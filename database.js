// database.js - Fixed coordinate handling
require('dotenv').config();
const { Pool } = require('pg');

// Database connection
const pool = new Pool({
  connectionString: process.env.DATABASE_URL,
  ssl: process.env.NODE_ENV === 'production' ? { rejectUnauthorized: false } : false
});

// Database initialization
async function initDatabase() {
  try {
    // Create users table
    await pool.query(`
      CREATE TABLE IF NOT EXISTS users (
        id VARCHAR(255) PRIMARY KEY,
        email VARCHAR(255) UNIQUE NOT NULL,
        name VARCHAR(255) NOT NULL,
        created_at TIMESTAMP DEFAULT NOW()
      );
    `);

    // Create help_requests table with proper coordinate types
    await pool.query(`
      CREATE TABLE IF NOT EXISTS help_requests (
        id SERIAL PRIMARY KEY,
        title VARCHAR(500) NOT NULL,
        description TEXT NOT NULL,
        latitude DECIMAL(10, 8) NOT NULL,
        longitude DECIMAL(11, 8) NOT NULL,
        contact VARCHAR(255) NOT NULL,
        urgency_level VARCHAR(20) DEFAULT 'Medium',
        status VARCHAR(20) DEFAULT 'Open',
        author_id VARCHAR(255) REFERENCES users(id),
        author_name VARCHAR(255) NOT NULL,
        helpers_count INTEGER DEFAULT 0,
        created_at TIMESTAMP DEFAULT NOW(),
        updated_at TIMESTAMP DEFAULT NOW()
      );
    `);

    // Create help_offers table
    await pool.query(`
      CREATE TABLE IF NOT EXISTS help_offers (
        id SERIAL PRIMARY KEY,
        request_id INTEGER REFERENCES help_requests(id),
        helper_id VARCHAR(255) REFERENCES users(id),
        helper_name VARCHAR(255) NOT NULL,
        created_at TIMESTAMP DEFAULT NOW(),
        UNIQUE(request_id, helper_id)
      );
    `);

    // Create indexes for performance
    await pool.query(`
      CREATE INDEX IF NOT EXISTS idx_requests_location ON help_requests(latitude, longitude);
      CREATE INDEX IF NOT EXISTS idx_requests_status ON help_requests(status);
      CREATE INDEX IF NOT EXISTS idx_requests_created ON help_requests(created_at);
    `);

    console.log('✅ Database initialized successfully');
  } catch (error) {
    console.error('❌ Database initialization error:', error);
  }
}

// Database operations
const db = {
  // Create or update user
  async upsertUser(userData) {
    const { id, email, name } = userData;
    const result = await pool.query(
      `INSERT INTO users (id, email, name) 
       VALUES ($1, $2, $3) 
       ON CONFLICT (email) DO UPDATE SET 
       name = EXCLUDED.name 
       RETURNING *`,
      [id, email, name]
    );
    return result.rows[0];
  },

  // Create help request with proper coordinate handling
  async createRequest(requestData) {
    const {
      title, description, latitude, longitude, contact,
      urgencyLevel, authorId, authorName
    } = requestData;
    
    console.log('🔧 Creating request with coordinates:', { latitude, longitude });
    console.log('🔧 Coordinate types:', typeof latitude, typeof longitude);
    
    // Ensure coordinates are properly converted to numbers
    const lat = typeof latitude === 'string' ? parseFloat(latitude) : latitude;
    const lng = typeof longitude === 'string' ? parseFloat(longitude) : longitude;
    
    console.log('🔧 Converted coordinates:', { lat, lng });
    
    if (isNaN(lat) || isNaN(lng)) {
      throw new Error(`Invalid coordinates: lat=${lat}, lng=${lng}`);
    }
    
    const result = await pool.query(
      `INSERT INTO help_requests 
       (title, description, latitude, longitude, contact, urgency_level, author_id, author_name)
       VALUES ($1, $2, $3, $4, $5, $6, $7, $8)
       RETURNING *`,
      [title, description, lat, lng, contact, urgencyLevel, authorId, authorName]
    );
    
    console.log('✅ Request created in database:', result.rows[0]);
    return result.rows[0];
  },

  // 🔥 FIXED: Get active requests with better debugging
  async getActiveRequests() {
    console.log('🔍 Querying for active requests...');
    
    const result = await pool.query(`
      SELECT r.*, 
            COALESCE(h.helpers_count, 0) as helpers_count
      FROM help_requests r
      LEFT JOIN (
        SELECT request_id, COUNT(*) as helpers_count
        FROM help_offers
        GROUP BY request_id
      ) h ON r.id = h.request_id
      WHERE r.created_at > NOW() - INTERVAL '24 hours'
        AND r.status NOT IN ('Completed', 'Cancelled')
      ORDER BY r.created_at DESC
    `);
    
    console.log(`🔍 Raw query result: ${result.rows.length} rows`);
    
    if (result.rows.length === 0) {
      console.log('⚠️ No rows found, checking total requests...');
      const totalResult = await pool.query('SELECT COUNT(*) FROM help_requests');
      console.log(`📊 Total requests in database: ${totalResult.rows[0].count}`);
      
      const recentResult = await pool.query(`
        SELECT COUNT(*) FROM help_requests 
        WHERE created_at > NOW() - INTERVAL '24 hours'
      `);
      console.log(`📊 Recent requests (24h): ${recentResult.rows[0].count}`);
      
      // 🔥 NEW: Check status distribution
      const statusResult = await pool.query(`
        SELECT status, COUNT(*) as count
        FROM help_requests 
        WHERE created_at > NOW() - INTERVAL '24 hours'
        GROUP BY status
      `);
      console.log('📊 Status distribution:', statusResult.rows);
    }
    
    const mappedResults = result.rows.map(row => {
      console.log('🔧 Processing row:', {
        id: row.id,
        title: row.title,
        status: row.status,
        helpers_count: row.helpers_count,
        created_at: row.created_at
      });
      
      return {
        id: row.id.toString(),
        title: row.title,
        description: row.description,
        latitude: parseFloat(row.latitude),
        longitude: parseFloat(row.longitude),
        contact: row.contact,
        urgencyLevel: row.urgency_level,
        status: row.status, // 🔥 IMPORTANT: This will now include "In Progress"
        createdAt: row.created_at,
        updatedAt: row.updated_at,
        authorId: row.author_id,
        authorName: row.author_name,
        helpersCount: parseInt(row.helpers_count) || 0
      };
    });
    
    console.log(`✅ Returning ${mappedResults.length} mapped requests`);
    console.log('📊 Status breakdown:', mappedResults.reduce((acc, req) => {
      acc[req.status] = (acc[req.status] || 0) + 1;
      return acc;
    }, {}));
    
    return mappedResults;
  },

  // Offer help
  async offerHelp(requestId, helperId, helperName) {
    const client = await pool.connect();
    try {
      await client.query('BEGIN');
      
      // Insert help offer
      await client.query(
        `INSERT INTO help_offers (request_id, helper_id, helper_name)
         VALUES ($1, $2, $3)
         ON CONFLICT (request_id, helper_id) DO NOTHING`,
        [requestId, helperId, helperName]
      );

      // Update request status if first helper
      const result = await client.query(
        `UPDATE help_requests 
         SET status = CASE 
           WHEN status = 'Open' THEN 'In Progress'
           ELSE status
         END,
         updated_at = NOW()
         WHERE id = $1
         RETURNING *`,
        [requestId]
      );

      await client.query('COMMIT');
      return result.rows[0];
    } catch (error) {
      await client.query('ROLLBACK');
      throw error;
    } finally {
      client.release();
    }
  },

  // Update request status
  async updateRequestStatus(requestId, status, authorId) {
    const result = await pool.query(
      `UPDATE help_requests 
       SET status = $1, updated_at = NOW()
       WHERE id = $2 AND author_id = $3
       RETURNING *`,
      [status, requestId, authorId]
    );
    return result.rows[0];
  },

  // 🔥 NEW: Debug function to check data integrity
  async debugRequests() {
    console.log('\n🔧 === DATABASE DEBUG ===');
    
    try {
      // Check total requests
      const totalResult = await pool.query('SELECT COUNT(*) FROM help_requests');
      console.log(`📊 Total requests: ${totalResult.rows[0].count}`);
      
      // Check recent requests
      const recentResult = await pool.query(`
        SELECT id, title, latitude, longitude, status, created_at
        FROM help_requests 
        ORDER BY created_at DESC 
        LIMIT 5
      `);
      
      console.log('📋 Recent requests:');
      recentResult.rows.forEach(row => {
        console.log(`  - ID: ${row.id}, Title: ${row.title}`);
        console.log(`    Coordinates: ${row.latitude}, ${row.longitude}`);
        console.log(`    Status: ${row.status}, Created: ${row.created_at}`);
      });
      
      // Check active requests query
      const activeResult = await pool.query(`
        SELECT COUNT(*) FROM help_requests 
        WHERE created_at > NOW() - INTERVAL '24 hours'
          AND status != 'Cancelled'
      `);
      console.log(`📊 Active requests (should match API): ${activeResult.rows[0].count}`);
      
    } catch (error) {
      console.error('❌ Debug query failed:', error);
    }
    
    console.log('🔧 === END DEBUG ===\n');
  },

  // Expose pool for direct queries
  pool
};

module.exports = { pool, initDatabase, db };
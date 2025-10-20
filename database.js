const { Pool } = require('pg');
require('dotenv').config();

const pool = new Pool({
  connectionString: process.env.DATABASE_URL,
  ssl: process.env.NODE_ENV === 'production' ? 
    { rejectUnauthorized: false } : false
});

// Database initialization with AI features
async function initDatabase() {
  try {
    console.log('🗄️ Initializing database tables...');
    
    // Create users table
    await pool.query(`
      CREATE TABLE IF NOT EXISTS users (
        id VARCHAR(255) PRIMARY KEY,
        email VARCHAR(255) UNIQUE NOT NULL,
        name VARCHAR(255) NOT NULL,
        created_at TIMESTAMP DEFAULT NOW()
      );
    `);

    // Create help_requests table (base structure)
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

    // Create AI insights table
    await pool.query(`
      CREATE TABLE IF NOT EXISTS ai_insights (
        id SERIAL PRIMARY KEY,
        request_id INTEGER REFERENCES help_requests(id),
        insight_type VARCHAR(50) NOT NULL,
        insight_data JSONB NOT NULL,
        created_at TIMESTAMP DEFAULT NOW()
      );
    `);

    // Create user AI preferences table
    await pool.query(`
      CREATE TABLE IF NOT EXISTS user_ai_preferences (
        user_id VARCHAR(255) PRIMARY KEY REFERENCES users(id),
        enable_ai_suggestions BOOLEAN DEFAULT true,
        enable_smart_notifications BOOLEAN DEFAULT true,
        preferred_categories TEXT[],
        notification_radius_miles DECIMAL(5, 2) DEFAULT 2.0,
        created_at TIMESTAMP DEFAULT NOW(),
        updated_at TIMESTAMP DEFAULT NOW()
      );
    `);

    // Create AI chat history table
    await pool.query(`
      CREATE TABLE IF NOT EXISTS ai_chat_history (
        id SERIAL PRIMARY KEY,
        user_id VARCHAR(255) REFERENCES users(id),
        message TEXT NOT NULL,
        response TEXT NOT NULL,
        context JSONB,
        created_at TIMESTAMP DEFAULT NOW()
      );
    `);

    console.log(' Base tables created successfully');
    
    // Now migrate AI columns to help_requests
    await migrateAIColumns();
    
    // Create indexes for performance
    await pool.query(`
      CREATE INDEX IF NOT EXISTS idx_requests_location ON help_requests(latitude, longitude);
      CREATE INDEX IF NOT EXISTS idx_requests_status ON help_requests(status);
      CREATE INDEX IF NOT EXISTS idx_requests_created ON help_requests(created_at);
      CREATE INDEX IF NOT EXISTS idx_requests_category ON help_requests(ai_category);
      CREATE INDEX IF NOT EXISTS idx_ai_insights_request ON ai_insights(request_id);
      CREATE INDEX IF NOT EXISTS idx_chat_history_user ON ai_chat_history(user_id);
    `);

    console.log(' Database initialized successfully with AI features');
  } catch (error) {
    console.error('  Database initialization error:', error);
    throw error;
  }
}

// Migrate AI columns to existing help_requests table
async function migrateAIColumns() {
  try {
    console.log('  Running AI column migration...');
    
    await pool.query(`
      DO $$ 
      BEGIN
        -- Add ai_category if it doesn't exist
        IF NOT EXISTS (
          SELECT 1 FROM information_schema.columns 
          WHERE table_name='help_requests' AND column_name='ai_category'
        ) THEN
          ALTER TABLE help_requests ADD COLUMN ai_category VARCHAR(50);
          RAISE NOTICE 'Added ai_category column';
        END IF;
        
        -- Add ai_category_icon if it doesn't exist
        IF NOT EXISTS (
          SELECT 1 FROM information_schema.columns 
          WHERE table_name='help_requests' AND column_name='ai_category_icon'
        ) THEN
          ALTER TABLE help_requests ADD COLUMN ai_category_icon VARCHAR(10);
          RAISE NOTICE 'Added ai_category_icon column';
        END IF;
        
        -- Add ai_category_name if it doesn't exist
        IF NOT EXISTS (
          SELECT 1 FROM information_schema.columns 
          WHERE table_name='help_requests' AND column_name='ai_category_name'
        ) THEN
          ALTER TABLE help_requests ADD COLUMN ai_category_name VARCHAR(100);
          RAISE NOTICE 'Added ai_category_name column';
        END IF;
        
        -- Add ai_detected_urgency if it doesn't exist
        IF NOT EXISTS (
          SELECT 1 FROM information_schema.columns 
          WHERE table_name='help_requests' AND column_name='ai_detected_urgency'
        ) THEN
          ALTER TABLE help_requests ADD COLUMN ai_detected_urgency VARCHAR(20);
          RAISE NOTICE 'Added ai_detected_urgency column';
        END IF;
        
        -- Add ai_estimated_time if it doesn't exist
        IF NOT EXISTS (
          SELECT 1 FROM information_schema.columns 
          WHERE table_name='help_requests' AND column_name='ai_estimated_time'
        ) THEN
          ALTER TABLE help_requests ADD COLUMN ai_estimated_time INTEGER;
          RAISE NOTICE 'Added ai_estimated_time column';
        END IF;
        
        -- Add ai_tags if it doesn't exist
        IF NOT EXISTS (
          SELECT 1 FROM information_schema.columns 
          WHERE table_name='help_requests' AND column_name='ai_tags'
        ) THEN
          ALTER TABLE help_requests ADD COLUMN ai_tags TEXT[];
          RAISE NOTICE 'Added ai_tags column';
        END IF;
        
        -- Add ai_suggested_title if it doesn't exist
        IF NOT EXISTS (
          SELECT 1 FROM information_schema.columns 
          WHERE table_name='help_requests' AND column_name='ai_suggested_title'
        ) THEN
          ALTER TABLE help_requests ADD COLUMN ai_suggested_title VARCHAR(500);
          RAISE NOTICE 'Added ai_suggested_title column';
        END IF;
        
        -- Add ai_safety_check if it doesn't exist
        IF NOT EXISTS (
          SELECT 1 FROM information_schema.columns 
          WHERE table_name='help_requests' AND column_name='ai_safety_check'
        ) THEN
          ALTER TABLE help_requests ADD COLUMN ai_safety_check VARCHAR(20) DEFAULT 'safe';
          RAISE NOTICE 'Added ai_safety_check column';
        END IF;
        
        -- Add ai_safety_reason if it doesn't exist
        IF NOT EXISTS (
          SELECT 1 FROM information_schema.columns 
          WHERE table_name='help_requests' AND column_name='ai_safety_reason'
        ) THEN
          ALTER TABLE help_requests ADD COLUMN ai_safety_reason TEXT;
          RAISE NOTICE 'Added ai_safety_reason column';
        END IF;
      END $$;
    `);
    
    console.log(' AI columns migrated successfully');
  } catch (error) {
    console.error('  AI column migration error:', error);
    throw error;
  }
}

// Database operations
const db = {
  pool,

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
    
    // Create default AI preferences for new users
    await pool.query(
      `INSERT INTO user_ai_preferences (user_id)
       VALUES ($1)
       ON CONFLICT (user_id) DO NOTHING`,
      [id]
    );
    
    return result.rows[0];
  },

  // Create help request with AI analysis
  async createRequest(requestData) {
    const {
      title, description, latitude, longitude, contact,
      urgencyLevel, authorId, authorName,
      // AI fields
      aiCategory, aiCategoryIcon, aiCategoryName,
      aiDetectedUrgency, aiEstimatedTime, aiTags,
      aiSuggestedTitle, aiSafetyCheck, aiSafetyReason
    } = requestData;
    
    const lat = typeof latitude === 'string' ? parseFloat(latitude) : latitude;
    const lng = typeof longitude === 'string' ? parseFloat(longitude) : longitude;
    
    if (isNaN(lat) || isNaN(lng)) {
      throw new Error(`Invalid coordinates: lat=${lat}, lng=${lng}`);
    }
    
    console.log('Creating request with AI data:', {
      title,
      aiCategory,
      aiCategoryName,
      aiTags
    });
    
    const result = await pool.query(
      `INSERT INTO help_requests 
       (title, description, latitude, longitude, contact, urgency_level, author_id, author_name,
        ai_category, ai_category_icon, ai_category_name, ai_detected_urgency, 
        ai_estimated_time, ai_tags, ai_suggested_title, ai_safety_check, ai_safety_reason)
       VALUES ($1, $2, $3, $4, $5, $6, $7, $8, $9, $10, $11, $12, $13, $14, $15, $16, $17)
       RETURNING *`,
      [title, description, lat, lng, contact, urgencyLevel, authorId, authorName,
       aiCategory, aiCategoryIcon, aiCategoryName, aiDetectedUrgency,
       aiEstimatedTime, aiTags, aiSuggestedTitle, aiSafetyCheck, aiSafetyReason]
    );
    
    console.log(' Request created with ID:', result.rows[0].id);
    return result.rows[0];
  },

  // Get active requests with AI data
  async getActiveRequests() {
    const result = await pool.query(`
      SELECT r.*, 
        COALESCE(h.helpers_count, 0) as helpers_count,
        COALESCE(h.active_helpers, 0) as active_helpers,
        COALESCE(h.completed_helpers, 0) as completed_helpers
      FROM help_requests r
      LEFT JOIN (
        SELECT request_id, 
          COUNT(*) as helpers_count,
          COUNT(CASE WHEN status != 'completed' THEN 1 END) as active_helpers,
          COUNT(CASE WHEN status = 'completed' THEN 1 END) as completed_helpers
        FROM help_offers
        GROUP BY request_id
      ) h ON r.id = h.request_id
      WHERE r.created_at > NOW() - INTERVAL '24 hours'
        AND r.status NOT IN ('completed', 'cancelled')
        AND (r.ai_safety_check = 'safe' OR r.ai_safety_check IS NULL)
      ORDER BY r.created_at DESC
    `);
    
    return result.rows;
  },

  // Offer help on a request
  async offerHelp(requestId, helperId, helperName) {
    const client = await pool.connect();
    try {
      await client.query('BEGIN');
      
      await client.query(
        `INSERT INTO help_offers (request_id, helper_id, helper_name)
         VALUES ($1, $2, $3)`,
        [requestId, helperId, helperName]
      );
      
      await client.query(
        `UPDATE help_requests 
         SET helpers_count = helpers_count + 1,
             updated_at = NOW()
         WHERE id = $1`,
        [requestId]
      );
      
      await client.query('COMMIT');
      
      const result = await client.query(
        'SELECT * FROM help_requests WHERE id = $1',
        [requestId]
      );
      
      return result.rows[0];
    } catch (error) {
      await client.query('ROLLBACK');
      throw error;
    } finally {
      client.release();
    }
  },

  // Save AI insight
  async saveAIInsight(requestId, insightType, insightData) {
    try {
      await pool.query(
        `INSERT INTO ai_insights (request_id, insight_type, insight_data)
         VALUES ($1, $2, $3)`,
        [requestId, insightType, JSON.stringify(insightData)]
      );
      console.log(' AI insight saved for request:', requestId);
    } catch (error) {
      console.error('  Failed to save AI insight:', error.message);
    }
  },

  // Get user AI preferences
  async getUserAIPreferences(userId) {
    const result = await pool.query(
      'SELECT * FROM user_ai_preferences WHERE user_id = $1',
      [userId]
    );
    return result.rows[0];
  },

  // Update user AI preferences
  async updateUserAIPreferences(userId, preferences) {
    const { enableAISuggestions, enableSmartNotifications, preferredCategories, notificationRadius } = preferences;
    
    await pool.query(
      `INSERT INTO user_ai_preferences 
       (user_id, enable_ai_suggestions, enable_smart_notifications, preferred_categories, notification_radius_miles, updated_at)
       VALUES ($1, $2, $3, $4, $5, NOW())
       ON CONFLICT (user_id) DO UPDATE SET
       enable_ai_suggestions = EXCLUDED.enable_ai_suggestions,
       enable_smart_notifications = EXCLUDED.enable_smart_notifications,
       preferred_categories = EXCLUDED.preferred_categories,
       notification_radius_miles = EXCLUDED.notification_radius_miles,
       updated_at = NOW()`,
      [userId, enableAISuggestions, enableSmartNotifications, preferredCategories, notificationRadius]
    );
  },

  // Save chat interaction
  async saveChatInteraction(userId, message, response, context) {
    await pool.query(
      `INSERT INTO ai_chat_history (user_id, message, response, context)
       VALUES ($1, $2, $3, $4)`,
      [userId, message, response, JSON.stringify(context)]
    );
  },

  // Get recent chat history for context
  async getChatHistory(userId, limit = 5) {
    const result = await pool.query(
      `SELECT message, response, context, created_at 
       FROM ai_chat_history 
       WHERE user_id = $1 
       ORDER BY created_at DESC 
       LIMIT $2`,
      [userId, limit]
    );
    return result.rows.reverse();
  }
};

module.exports = { initDatabase, db, pool };
// server.js - Enhanced CalPin Backend with Helper Status Tracking
const express = require('express');
const cors = require('cors');
const { OAuth2Client } = require('google-auth-library');
const { initDatabase, db } = require('./database');
require('dotenv').config();

const app = express();
const PORT = process.env.PORT || 3000;

// Google OAuth client for token verification
const client = new OAuth2Client(process.env.GOOGLE_CLIENT_ID);

// Enhanced CORS configuration
app.use(cors({
  origin: '*',
  methods: ['GET', 'POST', 'PUT', 'DELETE', 'OPTIONS'],
  allowedHeaders: ['Content-Type', 'Authorization', 'Accept']
}));

// Debug middleware to log incoming requests
app.use((req, res, next) => {
  console.log(`\n🔍 [${new Date().toISOString()}] ${req.method} ${req.url}`);
  console.log('📋 Headers:', JSON.stringify(req.headers, null, 2));
  console.log('🔗 Content-Type:', req.get('Content-Type'));
  console.log('🔐 Authorization:', req.get('Authorization') ? 'Bearer ' + req.get('Authorization').substring(7, 20) + '...' : 'None');
  next();
});

// Body parsing middleware
app.use(express.json({ 
  limit: '10mb',
  type: ['application/json', 'text/plain']
}));
app.use(express.urlencoded({ 
  extended: true, 
  limit: '10mb' 
}));

// Debug middleware to log parsed body
app.use((req, res, next) => {
  if (req.method === 'POST' || req.method === 'PUT') {
    console.log('📦 Raw Body Length:', req.get('Content-Length') || 'Unknown');
    console.log('📦 Parsed Body:', JSON.stringify(req.body, null, 2));
    console.log('📦 Body Type:', typeof req.body);
    console.log('📦 Body Keys:', Object.keys(req.body || {}));
  }
  next();
});

// Fallback requests for in-memory storage (only used if database fails)
let fallbackRequests = [];

// Database status
let databaseConnected = false;

// Initialize database on startup - clean version without sample data
async function startServer() {
  try {
    console.log('🗄️ Initializing database...');
    await initDatabase();
    databaseConnected = true;
    console.log('✅ Database connected successfully!');
    
    // Test database connection
    try {
      const existingRequests = await db.getActiveRequests();
      console.log(`✅ Database test successful, found ${existingRequests.length} existing requests`);
      console.log('🎯 Ready to accept new requests from users');
    } catch (testError) {
      console.log('⚠️ Database test failed:', testError.message);
      databaseConnected = false;
    }
    
  } catch (error) {
    console.error('❌ Database connection failed:', error.message);
    console.log('⚠️ Falling back to in-memory storage');
    databaseConnected = false;
  }
}

// Utility function to verify Google token
async function verifyGoogleToken(token) {
  try {
    console.log('🔍 Verifying Google token...');
    console.log('🔍 Token length:', token.length);
    console.log('🔍 Token starts with:', token.substring(0, 50) + '...');
    
    const ticket = await client.verifyIdToken({
      idToken: token,
      audience: process.env.GOOGLE_CLIENT_ID,
    });
    const payload = ticket.getPayload();
    
    console.log('🔍 Token payload received:', {
      email: payload.email,
      name: payload.name,
      sub: payload.sub,
      aud: payload.aud,
      iss: payload.iss
    });
    
    // Verify it's a Berkeley email
    if (!payload.email.endsWith('@berkeley.edu') && 
        !payload.email.endsWith('@student.berkeley.edu')) {
      throw new Error('Must use Berkeley email');
    }
    
    console.log('✅ Token verified for:', payload.email);
    return {
      id: payload.sub,
      email: payload.email,
      name: payload.name
    };
  } catch (error) {
    console.log('❌ Token verification failed:', error.message);
    throw new Error('Invalid token');
  }
}

// Middleware to authenticate requests
async function authenticateToken(req, res, next) {
  const authHeader = req.headers['authorization'];
  const token = authHeader && authHeader.replace('Bearer ', '');

  console.log('🔍 Auth check - Header present:', !!authHeader);
  console.log('🔍 Auth check - Token extracted:', !!token);
  console.log('🔍 Auth check - Token length:', token ? token.length : 0);

  if (!token) {
    console.log('❌ No token provided');
    return res.status(401).json({ error: 'Access token required' });
  }

  try {
    const user = await verifyGoogleToken(token);
    
    // Create or update user in database when they authenticate
    if (databaseConnected) {
      try {
        await db.upsertUser({
          id: user.id,
          email: user.email, 
          name: user.name
        });
        console.log('✅ User upserted in database:', user.email);
      } catch (dbError) {
        console.log('⚠️ Could not upsert user in database:', dbError.message);
      }
    }
    
    req.user = user;
    console.log('✅ User authenticated:', user.email);
    next();
  } catch (error) {
    console.error('❌ Auth error:', error.message);
    return res.status(403).json({ error: 'Invalid or expired token' });
  }
}

// Helper function to calculate distance between two points (in miles)
function calculateDistance(lat1, lon1, lat2, lon2) {
  const R = 3959; // Earth's radius in miles
  const dLat = (lat2 - lat1) * Math.PI / 180;
  const dLon = (lon2 - lon1) * Math.PI / 180;
  const a = Math.sin(dLat/2) * Math.sin(dLat/2) +
          Math.cos(lat1 * Math.PI / 180) * Math.cos(lat2 * Math.PI / 180) *
          Math.sin(dLon/2) * Math.sin(dLon/2);
  const c = 2 * Math.atan2(Math.sqrt(a), Math.sqrt(1-a));
  return R * c;
}

// Routes

// Enhanced health check
app.get('/health', async (req, res) => {
  console.log('🏥 Health check requested');
  
  let requestCount = 0;
  let dbStatus = 'disconnected';
  let dbError = null;
  let userCount = 0;
  
  if (databaseConnected) {
    try {
      const requests = await db.getActiveRequests();
      requestCount = requests.length;
      dbStatus = 'connected';
      
      // Try to get user count
      try {
        const userResult = await db.pool.query('SELECT COUNT(*) FROM users');
        userCount = parseInt(userResult.rows[0].count);
      } catch (userError) {
        console.log('⚠️ Could not get user count:', userError.message);
      }
      
      console.log('✅ Database health check passed');
    } catch (error) {
      console.log('⚠️ Database health check failed:', error.message);
      requestCount = fallbackRequests.length;
      dbStatus = 'error';
      dbError = error.message;
    }
  } else {
    requestCount = fallbackRequests.length;
  }
  
  res.json({ 
    status: 'healthy', 
    timestamp: new Date().toISOString(),
    requests_count: requestCount,
    users_count: userCount,
    database_status: dbStatus,
    database_error: dbError,
    environment: process.env.NODE_ENV || 'development',
    google_client_configured: !!process.env.GOOGLE_CLIENT_ID,
    database_url_configured: !!process.env.DATABASE_URL
  });
});

// GET /api/fetch - Retrieve all help requests WITH HELPER STATUS
app.get('/api/fetch', authenticateToken, async (req, res) => {
  try {
    console.log('📥 Fetching requests for user:', req.user.email);
    
    let activeRequests = [];
    
    if (databaseConnected) {
      try {
        console.log('🗄️ Fetching from database...');
        activeRequests = await db.getActiveRequests();
        console.log(`✅ Found ${activeRequests.length} requests in database`);
        
        // 🔥 NEW: Check which requests the current user is helping with
        const userId = req.user.id;
        if (activeRequests.length > 0) {
          const helpCheckQuery = `
            SELECT request_id 
            FROM help_offers 
            WHERE helper_id = $1 AND request_id = ANY($2::int[])
          `;
          
          const requestIds = activeRequests.map(r => parseInt(r.id));
          const helpResult = await db.pool.query(helpCheckQuery, [userId, requestIds]);
          const helpingRequestIds = new Set(helpResult.rows.map(row => row.request_id.toString()));
          
          console.log(`🔍 User ${userId} is helping with requests:`, Array.from(helpingRequestIds));
          
          // Add helping status to each request
          activeRequests = activeRequests.map(request => ({
            ...request,
            isCurrentUserHelping: helpingRequestIds.has(request.id.toString())
          }));
        }
        
      } catch (dbError) {
        console.log('❌ Database fetch failed:', dbError.message);
        console.log('⚠️ Falling back to in-memory storage');
        const now = new Date();
        activeRequests = fallbackRequests.filter(request => {
          const hoursSinceCreated = (now - new Date(request.createdAt)) / (1000 * 60 * 60);
          return hoursSinceCreated < 24 && request.status !== 'Cancelled';
        }).map(request => ({
          ...request,
          isCurrentUserHelping: request.helpers && request.helpers.includes(req.user.id)
        }));
      }
    } else {
      console.log('⚠️ Using fallback in-memory storage');
      const now = new Date();
      activeRequests = fallbackRequests.filter(request => {
        const hoursSinceCreated = (now - new Date(request.createdAt)) / (1000 * 60 * 60);
        return hoursSinceCreated < 24 && request.status !== 'Cancelled';
      }).map(request => ({
        ...request,
        isCurrentUserHelping: request.helpers && request.helpers.includes(req.user.id)
      }));
    }

    // Calculate distances if user location provided
    const userLat = parseFloat(req.query.lat);
    const userLon = parseFloat(req.query.lon);
    
    let responseRequests = activeRequests;
    
    if (userLat && userLon) {
      console.log('📍 Calculating distances from user location:', { userLat, userLon });
      responseRequests = activeRequests.map(request => ({
        ...request,
        distance: calculateDistance(userLat, userLon, request.latitude, request.longitude).toFixed(1) + 'mi',
        duration: Math.ceil(calculateDistance(userLat, userLon, request.latitude, request.longitude) * 15) + 'min'
      }));
    } else {
      responseRequests = activeRequests.map(request => ({
        ...request,
        distance: '0.5mi',
        duration: '5min'
      }));
    }

    console.log('✅ Returning', responseRequests.length, 'active requests with helper status');
    res.json(responseRequests);
  } catch (error) {
    console.error('❌ Fetch error:', error);
    res.status(500).json({ error: 'Failed to fetch requests' });
  }
});

// 🔥 NEW: GET /api/requests/:id/helper-status - Check if current user is helping
app.get('/api/requests/:id/helper-status', authenticateToken, async (req, res) => {
  try {
    const requestId = req.params.id;
    const userId = req.user.id;

    console.log('🔍 Checking helper status - Request ID:', requestId, 'User:', req.user.email);

    if (databaseConnected) {
      try {
        // Check if user is already helping with this request
        const result = await db.pool.query(
          'SELECT * FROM help_offers WHERE request_id = $1 AND helper_id = $2',
          [requestId, userId]
        );
        
        const isHelping = result.rows.length > 0;
        console.log(`✅ Helper status check: User ${userId} is ${isHelping ? 'helping' : 'not helping'} with request ${requestId}`);
        
        res.json({
          isHelping: isHelping,
          helpOfferedAt: isHelping ? result.rows[0].created_at : null
        });
        return;
      } catch (dbError) {
        console.log('❌ Database helper status check failed:', dbError.message);
        // Fall through to in-memory check
      }
    }

    // Fallback to in-memory storage
    const request = fallbackRequests.find(r => r.id === requestId);
    if (!request) {
      return res.status(404).json({ error: 'Request not found' });
    }

    const isHelping = request.helpers && request.helpers.includes(userId);
    res.json({
      isHelping: isHelping,
      helpOfferedAt: isHelping ? new Date() : null
    });

  } catch (error) {
    console.error('❌ Helper status check error:', error);
    res.status(500).json({ error: 'Failed to check helper status' });
  }
});

// POST /api/create - Create a new help request
app.post('/api/create', authenticateToken, async (req, res) => {
  try {
    console.log('\n🔧 === CREATE REQUEST DEBUG ===');
    console.log('🔨 Request received from:', req.user.email);
    console.log('📦 Body received:', JSON.stringify(req.body, null, 2));
    
    // Handle both direct object and nested object structures
    let requestData = req.body;
    
    if (req.body && typeof req.body === 'object' && Object.keys(req.body).length === 1) {
      const firstKey = Object.keys(req.body)[0];
      if (typeof req.body[firstKey] === 'object') {
        console.log('📦 Detected wrapped data, unwrapping...');
        requestData = req.body[firstKey];
      }
    }
    
    console.log('📦 Final request data:', JSON.stringify(requestData, null, 2));
    
    const {
      caption: title,
      description,
      address,
      contact,
      urgencyLevel = 'Medium',
      latitude,
      longitude
    } = requestData;

    console.log('📋 Extracted fields:');
    console.log('  - title:', title);
    console.log('  - description:', description);
    console.log('  - address:', address);
    console.log('  - contact:', contact);
    console.log('  - urgencyLevel:', urgencyLevel);
    console.log('  - latitude:', latitude);
    console.log('  - longitude:', longitude);
    console.log('  - user:', req.user);

    // Validation
    if (!title || !description || !address || !contact) {
      console.log('❌ Validation failed - missing required fields');
      return res.status(400).json({ 
        error: 'Missing required fields: title, description, address, contact',
        received: { title: !!title, description: !!description, address: !!address, contact: !!contact }
      });
    }

    if (!latitude || !longitude || isNaN(latitude) || isNaN(longitude)) {
      console.log('❌ Validation failed - invalid coordinates');
      return res.status(400).json({ 
        error: 'Invalid location coordinates',
        received: { latitude, longitude }
      });
    }

    const validUrgencyLevels = ['Low', 'Medium', 'High', 'Urgent'];
    if (!validUrgencyLevels.includes(urgencyLevel)) {
      console.log('❌ Validation failed - invalid urgency level');
      return res.status(400).json({ 
        error: 'Invalid urgency level. Must be: Low, Medium, High, or Urgent',
        received: urgencyLevel
      });
    }

    let newRequest;

    if (databaseConnected) {
      try {
        console.log('🗄️ Creating request in database...');
        console.log('👤 User info:', { id: req.user.id, name: req.user.name, email: req.user.email });
        
        newRequest = await db.createRequest({
          title,
          description,
          latitude: parseFloat(latitude),
          longitude: parseFloat(longitude),
          contact,
          urgencyLevel,
          authorId: req.user.id,
          authorName: req.user.name
        });
        console.log('✅ Request created in database with ID:', newRequest.id);
        
        // Verify the request was saved
        try {
          const verifyRequests = await db.getActiveRequests();
          const foundRequest = verifyRequests.find(r => r.id.toString() === newRequest.id.toString());
          if (foundRequest) {
            console.log('✅ Request verified in database');
          } else {
            console.log('⚠️ Request not found in verification check');
          }
        } catch (verifyError) {
          console.log('⚠️ Could not verify request creation:', verifyError.message);
        }
        
      } catch (dbError) {
        console.log('❌ Database create failed:', dbError.message);
        console.log('⚠️ Falling back to in-memory storage');
        
        newRequest = {
          id: Date.now().toString(),
          title,
          description,
          latitude: parseFloat(latitude),
          longitude: parseFloat(longitude),
          contact,
          urgencyLevel,
          status: 'Open',
          createdAt: new Date(),
          updatedAt: new Date(),
          authorId: req.user.id,
          authorName: req.user.name,
          helpersCount: 0,
          helpers: []
        };
        fallbackRequests.push(newRequest);
        databaseConnected = false;
      }
    } else {
      console.log('⚠️ Using fallback in-memory storage');
      newRequest = {
        id: Date.now().toString(),
        title,
        description,
        latitude: parseFloat(latitude),
        longitude: parseFloat(longitude),
        contact,
        urgencyLevel,
        status: 'Open',
        createdAt: new Date(),
        updatedAt: new Date(),
        authorId: req.user.id,
        authorName: req.user.name,
        helpersCount: 0,
        helpers: []
      };
      fallbackRequests.push(newRequest);
    }

    console.log('✅ Request created successfully with ID:', newRequest.id);
    console.log('📊 Total requests now:', databaseConnected ? 'In database' : fallbackRequests.length);
    console.log('🔧 === END CREATE REQUEST DEBUG ===\n');

    res.status(201).json({
      message: 'Request created successfully',
      request: newRequest,
      database_used: databaseConnected
    });

  } catch (error) {
    console.error('❌ Create error:', error);
    console.error('❌ Error stack:', error.stack);
    res.status(500).json({ 
      error: 'Failed to create request',
      details: error.message 
    });
  }
});

// POST /api/requests/:id/offer-help - Offer help for a request
app.post('/api/requests/:id/offer-help', authenticateToken, async (req, res) => {
  try {
    const requestId = req.params.id;
    const userId = req.user.id;
    const userName = req.user.name;

    console.log('🤝 User offering help:', req.user.email, 'for request:', requestId);

    if (databaseConnected) {
      try {
        const result = await db.offerHelp(requestId, userId, userName);
        console.log('✅ Help offered successfully in database');
        res.json({ 
          success: true, 
          message: 'Help offered successfully',
          request: result,
          database_used: true
        });
        return;
      } catch (dbError) {
        if (dbError.message && dbError.message.includes('duplicate key')) {
          return res.status(400).json({ error: 'You are already helping with this request' });
        }
        console.log('❌ Database offer help failed:', dbError.message);
        // Fall through to in-memory storage
      }
    }

    // Fallback to in-memory storage
    const requestIndex = fallbackRequests.findIndex(r => r.id === requestId);
    if (requestIndex === -1) {
      return res.status(404).json({ error: 'Request not found' });
    }

    const request = fallbackRequests[requestIndex];
    
    // Check if user already helping
    if (request.helpers && request.helpers.includes(userId)) {
      return res.status(400).json({ error: 'You are already helping with this request' });
    }

    // Check if it's the user's own request
    if (request.authorId === userId) {
      return res.status(400).json({ error: 'You cannot offer help on your own request' });
    }

    // Add helper
    if (!request.helpers) request.helpers = [];
    request.helpers.push(userId);
    request.helpersCount = request.helpers.length;
    
    if (request.status === 'Open') {
      request.status = 'In Progress';
    }
    
    request.updatedAt = new Date();
    
    console.log('⚠️ Help offered using fallback storage');
    res.json({ 
      success: true, 
      message: 'Help offered successfully',
      request: request,
      database_used: false
    });

  } catch (error) {
    console.error('❌ Offer help error:', error);
    res.status(500).json({ error: 'Failed to offer help' });
  }
});
// Add this endpoint to your server.js file
// 🔥 NEW: Helper marks their help as complete
app.post('/api/requests/:id/complete-help', authenticateToken, async (req, res) => {
  try {
    const requestId = req.params.id;
    const helperId = req.user.id;
    const helperName = req.user.name;

    console.log('✅ Helper completing help - Request ID:', requestId, 'Helper:', req.user.email);

    if (databaseConnected) {
      try {
        const client = await db.pool.connect();
        
        try {
          await client.query('BEGIN');
          
          // Check if helper is actually helping with this request
          const helperCheck = await client.query(
            'SELECT * FROM help_offers WHERE request_id = $1 AND helper_id = $2',
            [requestId, helperId]
          );
          
          if (helperCheck.rows.length === 0) {
            await client.query('ROLLBACK');
            return res.status(400).json({ error: 'You are not helping with this request' });
          }
          
          // Mark the help offer as completed
          await client.query(
            `UPDATE help_offers 
             SET completed_at = NOW()
             WHERE request_id = $1 AND helper_id = $2`,
            [requestId, helperId]
          );
          
          // Check if this was the last active helper
          const activeHelpersResult = await client.query(
            `SELECT COUNT(*) as count FROM help_offers 
             WHERE request_id = $1 AND completed_at IS NULL`,
            [requestId]
          );
          
          const activeHelpersCount = parseInt(activeHelpersResult.rows[0].count);
          
          // Get request details
          const requestResult = await client.query(
            'SELECT * FROM help_requests WHERE id = $1',
            [requestId]
          );
          
          if (requestResult.rows.length === 0) {
            await client.query('ROLLBACK');
            return res.status(404).json({ error: 'Request not found' });
          }
          
          const request = requestResult.rows[0];
          
          // If no more active helpers, mark request as completed
          // (You can change this logic based on your workflow preference)
          if (activeHelpersCount === 0) {
            await client.query(
              `UPDATE help_requests 
               SET status = 'Completed', updated_at = NOW()
               WHERE id = $1`,
              [requestId]
            );
          }
          
          await client.query('COMMIT');
          
          console.log(`✅ Helper ${helperId} marked help as complete for request ${requestId}`);
          
          res.json({
            success: true,
            message: 'Help marked as complete',
            request_status: activeHelpersCount === 0 ? 'Completed' : 'In Progress',
            active_helpers: activeHelpersCount
          });
          
        } catch (error) {
          await client.query('ROLLBACK');
          throw error;
        } finally {
          client.release();
        }
        
      } catch (dbError) {
        console.log('❌ Database complete help failed:', dbError.message);
        return res.status(500).json({ error: 'Database error' });
      }
    } else {
      // Fallback logic for in-memory storage
      const requestIndex = fallbackRequests.findIndex(r => r.id === requestId);
      if (requestIndex === -1) {
        return res.status(404).json({ error: 'Request not found' });
      }
      
      const request = fallbackRequests[requestIndex];
      
      if (!request.helpers || !request.helpers.includes(helperId)) {
        return res.status(400).json({ error: 'You are not helping with this request' });
      }
      
      // Mark helper as completed
      if (!request.completedHelpers) request.completedHelpers = [];
      request.completedHelpers.push(helperId);
      
      // Remove from active helpers
      request.helpers = request.helpers.filter(h => h !== helperId);
      request.helpersCount = request.helpers.length;
      
      // If no more active helpers, mark as completed
      if (request.helpers.length === 0) {
        request.status = 'Completed';
      }
      
      request.updatedAt = new Date();
      
      res.json({
        success: true,
        message: 'Help marked as complete',
        request_status: request.status,
        active_helpers: request.helpers.length
      });
    }

  } catch (error) {
    console.error('❌ Complete help error:', error);
    res.status(500).json({ error: 'Failed to complete help' });
  }
});

// 🔥 OPTIONAL: Also add this endpoint for requester confirmation workflow
app.post('/api/requests/:id/confirm-completion', authenticateToken, async (req, res) => {
  try {
    const requestId = req.params.id;
    const requesterId = req.user.id;
    const { confirmed, stillNeedHelp } = req.body;

    console.log('🎯 Requester confirming completion - Request ID:', requestId, 'Confirmed:', confirmed);

    if (databaseConnected) {
      try {
        // Check if user is the requester
        const requestResult = await db.pool.query(
          'SELECT * FROM help_requests WHERE id = $1 AND author_id = $2',
          [requestId, requesterId]
        );
        
        if (requestResult.rows.length === 0) {
          return res.status(404).json({ error: 'Request not found or unauthorized' });
        }
        
        if (confirmed && !stillNeedHelp) {
          // Mark request as completed
          await db.pool.query(
            `UPDATE help_requests 
             SET status = 'Completed', updated_at = NOW()
             WHERE id = $1`,
            [requestId]
          );
          
          res.json({
            success: true,
            message: 'Request marked as completed',
            status: 'Completed'
          });
          
        } else if (stillNeedHelp) {
          // Reset to "In Progress"
          await db.pool.query(
            `UPDATE help_requests 
             SET status = 'In Progress', updated_at = NOW()
             WHERE id = $1`,
            [requestId]
          );
          
          res.json({
            success: true,
            message: 'Request reset to in-progress',
            status: 'In Progress'
          });
        } else {
          return res.status(400).json({ error: 'Invalid completion parameters' });
        }
        
      } catch (dbError) {
        console.log('❌ Database confirm completion failed:', dbError.message);
        return res.status(500).json({ error: 'Database error' });
      }
    } else {
      // Fallback logic for in-memory storage
      const requestIndex = fallbackRequests.findIndex(r => r.id === requestId && r.authorId === requesterId);
      if (requestIndex === -1) {
        return res.status(404).json({ error: 'Request not found or unauthorized' });
      }
      
      if (confirmed && !stillNeedHelp) {
        fallbackRequests[requestIndex].status = 'Completed';
      } else if (stillNeedHelp) {
        fallbackRequests[requestIndex].status = 'In Progress';
      }
      
      fallbackRequests[requestIndex].updatedAt = new Date();
      
      res.json({
        success: true,
        message: 'Request status updated',
        status: fallbackRequests[requestIndex].status
      });
    }

  } catch (error) {
    console.error('❌ Confirm completion error:', error);
    res.status(500).json({ error: 'Failed to confirm completion' });
  }
});

// 🔥 NEW: PUT /api/requests/:id/status - Update request status
app.put('/api/requests/:id/status', authenticateToken, async (req, res) => {
  try {
    const requestId = req.params.id;
    const { status } = req.body;
    const userId = req.user.id;

    console.log('📝 Updating request status:', requestId, 'to:', status, 'by:', req.user.email);

    if (!['Open', 'In Progress', 'Completed', 'Cancelled'].includes(status)) {
      return res.status(400).json({ error: 'Invalid status' });
    }

    if (databaseConnected) {
      try {
        const result = await db.updateRequestStatus(requestId, status, userId);
        if (!result) {
          return res.status(404).json({ error: 'Request not found or unauthorized' });
        }
        
        console.log('✅ Request status updated in database');
        res.json({ 
          success: true, 
          message: 'Status updated successfully',
          request: result,
          database_used: true
        });
        return;
      } catch (dbError) {
        console.log('❌ Database status update failed:', dbError.message);
        // Fall through to in-memory storage
      }
    }

    // Fallback to in-memory storage
    const requestIndex = fallbackRequests.findIndex(r => r.id === requestId && r.authorId === userId);
    if (requestIndex === -1) {
      return res.status(404).json({ error: 'Request not found or unauthorized' });
    }

    fallbackRequests[requestIndex].status = status;
    fallbackRequests[requestIndex].updatedAt = new Date();
    
    console.log('⚠️ Request status updated using fallback storage');
    res.json({ 
      success: true, 
      message: 'Status updated successfully',
      request: fallbackRequests[requestIndex],
      database_used: false
    });

  } catch (error) {
    console.error('❌ Update status error:', error);
    res.status(500).json({ error: 'Failed to update status' });
  }
});

// 🔥 NEW: GET /api/user/stats - User statistics
// Enhanced user stats implementation for server.js
// Replace the existing /api/user/stats endpoint
app.get('/api/user/stats', authenticateToken, async (req, res) => {
  try {
    const userId = req.user.id;
    console.log('📊 Fetching dynamic stats for user:', req.user.email);
    
    let stats = {
      requestsMade: 0,
      peopleHelped: 0,
      communityPoints: 0,
      thisWeek: 0,
      currentStreak: 0,
      totalConnectionsMade: 0,
      avgResponseTime: 0,
      completionRate: 0,
      joinDate: new Date(),
      lastActivity: null,
      topCategories: [],
      weeklyActivity: []
    };

    if (databaseConnected) {
      try {
        const client = await db.pool.connect();
        
        try {
          // 1. Get user's requests made
          const requestsResult = await client.query(
            'SELECT COUNT(*) as count, MIN(created_at) as first_request FROM help_requests WHERE author_id = $1',
            [userId]
          );
          stats.requestsMade = parseInt(requestsResult.rows[0].count) || 0;
          
          // 2. Get help offers made by user (people helped)
          const helpResult = await client.query(`
            SELECT COUNT(DISTINCT ho.request_id) as unique_requests_helped,
                   COUNT(*) as total_help_offers,
                   MAX(ho.created_at) as last_help_offered
            FROM help_offers ho 
            WHERE ho.helper_id = $1
          `, [userId]);
          
          const helpStats = helpResult.rows[0];
          stats.peopleHelped = parseInt(helpStats.unique_requests_helped) || 0;
          // Convert lastActivity to ISO string if it exists
          if (helpStats.last_help_offered) {
            stats.lastActivity = new Date(helpStats.last_help_offered).toISOString();
          }

          // 3. Get recent activity (this week)
          const weekAgoResult = await client.query(`
            SELECT COUNT(DISTINCT ho.request_id) as requests_helped_this_week,
                   COUNT(*) as total_actions_this_week
            FROM help_offers ho 
            WHERE ho.helper_id = $1 AND ho.created_at > NOW() - INTERVAL '7 days'
          `, [userId]);
          
          stats.thisWeek = parseInt(weekAgoResult.rows[0].requests_helped_this_week) || 0;

          // 4. Calculate community points (dynamic scoring system)
          const pointsResult = await client.query(`
            SELECT 
              COUNT(DISTINCT ho.request_id) as unique_requests_helped,
              COUNT(CASE WHEN hr.urgency_level = 'Urgent' THEN 1 END) as urgent_helps,
              COUNT(CASE WHEN hr.urgency_level = 'High' THEN 1 END) as high_helps,
              COUNT(CASE WHEN hr.urgency_level = 'Medium' THEN 1 END) as medium_helps,
              COUNT(CASE WHEN hr.urgency_level = 'Low' THEN 1 END) as low_helps,
              COUNT(CASE WHEN ho.created_at > NOW() - INTERVAL '24 hours' THEN 1 END) as quick_responses
            FROM help_offers ho
            JOIN help_requests hr ON ho.request_id = hr.id
            WHERE ho.helper_id = $1
          `, [userId]);

          const points = pointsResult.rows[0];
          // Dynamic point calculation
          stats.communityPoints = 
            (parseInt(points.urgent_helps) || 0) * 25 +     // 25 points for urgent help
            (parseInt(points.high_helps) || 0) * 15 +       // 15 points for high priority
            (parseInt(points.medium_helps) || 0) * 10 +     // 10 points for medium priority
            (parseInt(points.low_helps) || 0) * 5 +         // 5 points for low priority
            (parseInt(points.quick_responses) || 0) * 5 +   // 5 bonus points for quick responses
            stats.requestsMade * 2;                         // 2 points for each request made

          // 5. Calculate current streak (consecutive weeks with at least 1 help)
          const streakResult = await client.query(`
            WITH weekly_activity AS (
              SELECT 
                DATE_TRUNC('week', ho.created_at) as week,
                COUNT(DISTINCT ho.request_id) as helps_count
              FROM help_offers ho
              WHERE ho.helper_id = $1
                AND ho.created_at >= NOW() - INTERVAL '20 weeks'
              GROUP BY DATE_TRUNC('week', ho.created_at)
              ORDER BY week DESC
            ),
            streak_calc AS (
              SELECT 
                week,
                helps_count,
                ROW_NUMBER() OVER (ORDER BY week DESC) as week_rank,
                CASE 
                  WHEN helps_count > 0 THEN 1 
                  ELSE 0 
                END as has_activity
              FROM weekly_activity
            )
            SELECT COUNT(*) as streak
            FROM streak_calc 
            WHERE has_activity = 1 
              AND week_rank <= (
                SELECT COALESCE(MIN(week_rank), 0)
                FROM streak_calc 
                WHERE has_activity = 0 AND week_rank > 0
              )
          `, [userId]);

          stats.currentStreak = parseInt(streakResult.rows[0].streak) || 0;

          // 6. Calculate completion rate
          const completionResult = await client.query(`
            SELECT 
              COUNT(*) as total_requests_made,
              COUNT(CASE WHEN hr.status = 'Completed' THEN 1 END) as completed_requests
            FROM help_requests hr
            WHERE hr.author_id = $1
          `, [userId]);

          const completion = completionResult.rows[0];
          if (parseInt(completion.total_requests_made) > 0) {
            stats.completionRate = Math.round(
              (parseInt(completion.completed_requests) / parseInt(completion.total_requests_made)) * 100
            );
          }

          // 7. Get weekly activity for the past 7 weeks
          const weeklyActivityResult = await client.query(`
            SELECT 
              DATE_TRUNC('week', ho.created_at) as week,
              COUNT(DISTINCT ho.request_id) as helps_count
            FROM help_offers ho
            WHERE ho.helper_id = $1
              AND ho.created_at >= NOW() - INTERVAL '7 weeks'
            GROUP BY DATE_TRUNC('week', ho.created_at)
            ORDER BY week DESC
            LIMIT 7
          `, [userId]);

          stats.weeklyActivity = weeklyActivityResult.rows.map(row => ({
            week: row.week.toISOString(),
            helpsCount: parseInt(row.helps_count)
          }));

          // 8. Get user join date from users table
          const userResult = await client.query(
            'SELECT created_at FROM users WHERE id = $1',
            [userId]
          );
          
          if (userResult.rows.length > 0) {
            stats.joinDate = userResult.rows[0].created_at.toISOString();
          } else {
            stats.joinDate = new Date().toISOString();
          }

          // 9. Calculate total connections made (unique people helped + people who helped user)
          const connectionsResult = await client.query(`
            SELECT COUNT(DISTINCT connections.user_id) as total_connections
            FROM (
              SELECT hr.author_id as user_id
              FROM help_offers ho
              JOIN help_requests hr ON ho.request_id = hr.id
              WHERE ho.helper_id = $1
              UNION
              SELECT ho.helper_id as user_id
              FROM help_offers ho
              JOIN help_requests hr ON ho.request_id = hr.id
              WHERE hr.author_id = $1
            ) connections
            WHERE connections.user_id != $1
          `, [userId, userId]);

          stats.totalConnectionsMade = parseInt(connectionsResult.rows[0].total_connections) || 0;

          console.log('✅ Dynamic stats calculated successfully:', stats);
          
        } finally {
          client.release();
        }
        
      } catch (dbError) {
        console.log('❌ Database stats calculation failed:', dbError.message);
        // Return default stats if database fails
        stats = {
          requestsMade: 0,
          peopleHelped: 0,
          communityPoints: 0,
          thisWeek: 0,
          currentStreak: 0,
          totalConnectionsMade: 0,
          completionRate: 0,
          joinDate: new Date(),
          lastActivity: null,
          weeklyActivity: []
        };
      }
    } else {
      // Fallback calculation using in-memory data
      const userRequests = fallbackRequests.filter(r => r.authorId === userId);
      const userHelps = fallbackRequests.filter(r => 
        r.helpers && r.helpers.includes(userId) ||
        r.completedHelpers && r.completedHelpers.includes(userId)
      );

      stats.requestsMade = userRequests.length;
      stats.peopleHelped = userHelps.length;
      stats.communityPoints = userHelps.length * 10 + userRequests.length * 2;
      
      // Calculate this week's activity
      const oneWeekAgo = new Date();
      oneWeekAgo.setDate(oneWeekAgo.getDate() - 7);
      stats.thisWeek = userHelps.filter(r => new Date(r.createdAt) > oneWeekAgo).length;
    }

    res.json(stats);
  } catch (error) {
    console.error('❌ User stats error:', error);
    res.status(500).json({ error: 'Failed to get user stats' });
  }
});

// 🔥 NEW: GET /api/user/achievements - Get user achievements
app.get('/api/user/achievements', authenticateToken, async (req, res) => {
  try {
    const userId = req.user.id;
    console.log('🏆 Fetching achievements for user:', req.user.email);

    let achievements = [];

    if (databaseConnected) {
      try {
        // Get user stats first by calling our stats endpoint
        const statsResult = await db.pool.query(`
          SELECT 
            COUNT(DISTINCT hr.id) as requests_made,
            COUNT(DISTINCT ho.request_id) as people_helped,
            COUNT(DISTINCT ho.request_id) * 10 + COUNT(DISTINCT hr.id) * 2 as community_points
          FROM users u
          LEFT JOIN help_requests hr ON hr.author_id = u.id  
          LEFT JOIN help_offers ho ON ho.helper_id = u.id
          WHERE u.id = $1
        `, [userId]);
        
        const stats = statsResult.rows[0];
        const requestsMade = parseInt(stats.requests_made) || 0;
        const peopleHelped = parseInt(stats.people_helped) || 0;
        const communityPoints = parseInt(stats.community_points) || 0;
        
        // Calculate current streak (simplified)
        const streakResult = await db.pool.query(`
          SELECT COUNT(DISTINCT DATE_TRUNC('week', ho.created_at)) as active_weeks
          FROM help_offers ho
          WHERE ho.helper_id = $1 
            AND ho.created_at >= NOW() - INTERVAL '4 weeks'
        `, [userId]);
        
        const currentStreak = parseInt(streakResult.rows[0].active_weeks) || 0;
        
        // Define achievement criteria and calculate earned achievements
        const achievementCriteria = [
          {
            id: 'first_help',
            name: 'First Helper',
            description: 'Offered help for the first time',
            icon: '🤝',
            condition: peopleHelped >= 1,
            progress: Math.min(peopleHelped, 1),
            target: 1,
            earned: peopleHelped >= 1,
            earnedAt: peopleHelped >= 1 ? new Date().toISOString() : null
          },
          {
            id: 'helper_5',
            name: 'Community Helper',
            description: 'Helped 5 different people',
            icon: '⭐',
            condition: peopleHelped >= 5,
            progress: peopleHelped,
            target: 5,
            earned: peopleHelped >= 5,
            earnedAt: peopleHelped >= 5 ? new Date().toISOString() : null
          },
          {
            id: 'helper_25',
            name: 'Super Helper',
            description: 'Helped 25 different people',
            icon: '🌟',
            condition: peopleHelped >= 25,
            progress: peopleHelped,
            target: 25,
            earned: peopleHelped >= 25,
            earnedAt: peopleHelped >= 25 ? new Date().toISOString() : null
          },
          {
            id: 'streak_1',
            name: 'Week Warrior',
            description: 'Maintained a 1-week helping streak',
            icon: '🔥',
            condition: currentStreak >= 1,
            progress: currentStreak,
            target: 1,
            earned: currentStreak >= 1,
            earnedAt: currentStreak >= 1 ? new Date().toISOString() : null
          },
          {
            id: 'streak_4',
            name: 'Monthly Champion',
            description: 'Maintained a 4-week helping streak',
            icon: '🏆',
            condition: currentStreak >= 4,
            progress: currentStreak,
            target: 4,
            earned: currentStreak >= 4,
            earnedAt: currentStreak >= 4 ? new Date().toISOString() : null
          },
          {
            id: 'points_100',
            name: 'Point Collector',
            description: 'Earned 100 community points',
            icon: '💎',
            condition: communityPoints >= 100,
            progress: communityPoints,
            target: 100,
            earned: communityPoints >= 100,
            earnedAt: communityPoints >= 100 ? new Date().toISOString() : null
          },
          {
            id: 'requester',
            name: 'Help Seeker',
            description: 'Made your first help request',
            icon: '🙋‍♂️',
            condition: requestsMade >= 1,
            progress: Math.min(requestsMade, 1),
            target: 1,
            earned: requestsMade >= 1,
            earnedAt: requestsMade >= 1 ? new Date().toISOString() : null
          }
        ];

        achievements = achievementCriteria;

      } catch (error) {
        console.log('❌ Achievement calculation failed:', error.message);
      }
    }

    console.log(`✅ Returning ${achievements.length} achievements`);
    res.json(achievements);
  } catch (error) {
    console.error('❌ Achievements error:', error);
    res.status(500).json({ error: 'Failed to get achievements' });
  }
});

// 🔥 NEW: GET /api/user/activity-timeline - Get user activity timeline
app.get('/api/user/activity-timeline', authenticateToken, async (req, res) => {
  try {
    const userId = req.user.id;
    const limit = parseInt(req.query.limit) || 20;
    
    console.log('📅 Fetching activity timeline for user:', req.user.email);

    let timeline = [];

    if (databaseConnected) {
      try {
        const result = await db.pool.query(`
          SELECT 
            'help_offered' as activity_type,
            ho.created_at as timestamp,
            hr.title as request_title,
            hr.urgency_level,
            hr.author_name,
            ho.request_id::text,
            NULL as status_change
          FROM help_offers ho
          JOIN help_requests hr ON ho.request_id = hr.id
          WHERE ho.helper_id = $1
          
          UNION ALL
          
          SELECT 
            'request_created' as activity_type,
            hr.created_at as timestamp,
            hr.title as request_title,
            hr.urgency_level,
            NULL as author_name,
            hr.id::text as request_id,
            hr.status as status_change
          FROM help_requests hr
          WHERE hr.author_id = $1
          
          ORDER BY timestamp DESC
          LIMIT $2
        `, [userId, limit]);

        timeline = result.rows.map(row => ({
          activityType: row.activity_type,
          timestamp: row.timestamp.toISOString(),
          requestTitle: row.request_title,
          urgencyLevel: row.urgency_level,
          authorName: row.author_name,
          requestId: parseInt(row.request_id),
          statusChange: row.status_change
        }));

        console.log(`✅ Activity timeline: ${timeline.length} items`);

      } catch (dbError) {
        console.log('❌ Timeline query failed:', dbError.message);
      }
    }

    res.json(timeline);
  } catch (error) {
    console.error('❌ Activity timeline error:', error);
    res.status(500).json({ error: 'Failed to get activity timeline' });
  }
});

app.get('/api/user/history', authenticateToken, async (req, res) => {
  try {
    const userId = req.user.id;
    
    console.log('📚 Fetching history for user:', req.user.email);

    if (databaseConnected) {
      try {
        // Get requests user created
        const createdRequestsResult = await pool.query(`
          SELECT r.*, 
                 COALESCE(h.helpers_count, 0) as helpers_count,
                 COALESCE(h.completed_helpers, 0) as completed_helpers
          FROM help_requests r
          LEFT JOIN (
            SELECT request_id, 
                   COUNT(*) as helpers_count,
                   COUNT(CASE WHEN status = 'completed' THEN 1 END) as completed_helpers
            FROM help_offers
            GROUP BY request_id
          ) h ON r.id = h.request_id
          WHERE r.author_id = $1
          ORDER BY r.created_at DESC
        `, [userId]);
        
        // Get requests user helped with
        const helpedRequestsResult = await pool.query(`
          SELECT r.*, ho.status as help_status, ho.created_at as help_offered_at, 
                 ho.completed_at, COALESCE(h.helpers_count, 0) as helpers_count
          FROM help_requests r
          JOIN help_offers ho ON r.id = ho.request_id
          LEFT JOIN (
            SELECT request_id, COUNT(*) as helpers_count
            FROM help_offers
            GROUP BY request_id
          ) h ON r.id = h.request_id
          WHERE ho.helper_id = $1
          ORDER BY ho.created_at DESC
        `, [userId]);
        
        res.json({
          success: true,
          created_requests: createdRequestsResult.rows.map(row => ({
            id: row.id.toString(),
            title: row.title,
            description: row.description,
            status: row.status,
            urgencyLevel: row.urgency_level,
            createdAt: row.created_at,
            updatedAt: row.updated_at,
            helpersCount: parseInt(row.helpers_count) || 0,
            completedHelpers: parseInt(row.completed_helpers) || 0,
            latitude: parseFloat(row.latitude),
            longitude: parseFloat(row.longitude)
          })),
          helped_requests: helpedRequestsResult.rows.map(row => ({
            id: row.id.toString(),
            title: row.title,
            description: row.description,
            requestStatus: row.status,
            helpStatus: row.help_status,
            urgencyLevel: row.urgency_level,
            helpOfferedAt: row.help_offered_at,
            helpCompletedAt: row.completed_at,
            authorName: row.author_name,
            helpersCount: parseInt(row.helpers_count) || 0,
            latitude: parseFloat(row.latitude),
            longitude: parseFloat(row.longitude)
          }))
        });
        
      } catch (dbError) {
        console.log('❌ Database history fetch failed:', dbError.message);
        return res.status(500).json({ error: 'Database error' });
      }
    } else {
      // Fallback logic
      const createdRequests = fallbackRequests.filter(r => r.authorId === userId);
      const helpedRequests = fallbackRequests.filter(r => 
        r.helpers && r.helpers.includes(userId) ||
        r.completedHelpers && r.completedHelpers.includes(userId)
      );
      
      res.json({
        success: true,
        created_requests: createdRequests,
        helped_requests: helpedRequests.map(r => ({
          ...r,
          helpStatus: r.completedHelpers && r.completedHelpers.includes(userId) ? 'completed' : 'active'
        }))
      });
    }

  } catch (error) {
    console.error('❌ History fetch error:', error);
    res.status(500).json({ error: 'Failed to fetch history' });
  }
});

// Test endpoint for debugging
app.post('/api/test', (req, res) => {
  console.log('\n🧪 === TEST ENDPOINT ===');
  console.log('📦 Headers:', req.headers);
  console.log('📦 Body:', req.body);
  console.log('📦 Raw body type:', typeof req.body);
  console.log('🧪 === END TEST ===\n');
  
  res.json({
    message: 'Test endpoint reached',
    receivedBody: req.body,
    bodyType: typeof req.body,
    headers: req.headers,
    databaseStatus: databaseConnected ? 'connected' : 'disconnected',
    environment: process.env.NODE_ENV || 'development',
    timestamp: new Date().toISOString()
  });
});

// Database diagnostics endpoint
app.get('/api/debug/database', authenticateToken, async (req, res) => {
  const diagnostics = {
    connected: databaseConnected,
    environment: process.env.NODE_ENV,
    database_url_configured: !!process.env.DATABASE_URL,
    fallback_requests_count: fallbackRequests.length
  };

  if (databaseConnected) {
    try {
      const requests = await db.getActiveRequests();
      const usersResult = await db.pool.query('SELECT COUNT(*) FROM users');
      diagnostics.database_requests_count = requests.length;
      diagnostics.database_users_count = parseInt(usersResult.rows[0].count);
      diagnostics.database_test = 'success';
    } catch (error) {
      diagnostics.database_test = 'failed';
      diagnostics.database_error = error.message;
    }
  }

  res.json(diagnostics);
});

// 🔥 NEW: Debug endpoint to check database state
app.get('/api/debug/requests', authenticateToken, async (req, res) => {
  try {
    console.log('🔧 Debug endpoint called by:', req.user.email);
    
    if (!databaseConnected) {
      return res.json({
        error: 'Database not connected',
        fallback_requests: fallbackRequests.length,
        requests: fallbackRequests
      });
    }

    // Check total requests
    const totalResult = await db.pool.query('SELECT COUNT(*) FROM help_requests');
    const totalCount = parseInt(totalResult.rows[0].count);

    // Check recent requests
    const recentResult = await db.pool.query(`
      SELECT id, title, latitude, longitude, status, created_at, author_name
      FROM help_requests 
      ORDER BY created_at DESC 
      LIMIT 10
    `);

    // Check active requests (same query as getActiveRequests)
    const activeResult = await db.pool.query(`
      SELECT r.*, 
             COALESCE(h.helpers_count, 0) as helpers_count
      FROM help_requests r
      LEFT JOIN (
        SELECT request_id, COUNT(*) as helpers_count
        FROM help_offers
        GROUP BY request_id
      ) h ON r.id = h.request_id
      WHERE r.created_at > NOW() - INTERVAL '24 hours'
        AND r.status != 'Cancelled'
      ORDER BY r.created_at DESC
    `);

    // Check if coordinates are valid
    const coordinateCheck = await db.pool.query(`
      SELECT id, title, latitude, longitude,
             CASE 
               WHEN latitude IS NULL THEN 'NULL'
               WHEN latitude::text = '' THEN 'EMPTY'
               WHEN latitude = 0 THEN 'ZERO'
               ELSE 'VALID'
             END as lat_status,
             CASE 
               WHEN longitude IS NULL THEN 'NULL'
               WHEN longitude::text = '' THEN 'EMPTY'
               WHEN longitude = 0 THEN 'ZERO'
               ELSE 'VALID'
             END as lng_status
      FROM help_requests 
      ORDER BY created_at DESC 
      LIMIT 5
    `);

    res.json({
      database_connected: databaseConnected,
      total_requests: totalCount,
      active_requests_count: activeResult.rows.length,
      recent_requests: recentResult.rows.map(row => ({
        id: row.id,
        title: row.title,
        latitude: row.latitude,
        longitude: row.longitude,
        status: row.status,
        created_at: row.created_at,
        author_name: row.author_name
      })),
      active_requests: activeResult.rows.map(row => ({
        id: row.id,
        title: row.title,
        latitude: parseFloat(row.latitude),
        longitude: parseFloat(row.longitude),
        status: row.status,
        helpers_count: row.helpers_count
      })),
      coordinate_validation: coordinateCheck.rows,
      query_timestamp: new Date().toISOString()
    });

  } catch (error) {
    console.error('❌ Debug endpoint error:', error);
    res.status(500).json({ 
      error: 'Debug failed',
      message: error.message,
      stack: error.stack
    });
  }
});

// 🔥 NEW: Simplified test endpoint to check basic functionality
app.get('/api/test-fetch', authenticateToken, async (req, res) => {
  try {
    console.log('🧪 Test fetch called');
    
    if (databaseConnected) {
      // Simple direct query without complex joins
      const result = await db.pool.query(`
        SELECT id, title, latitude, longitude, status, created_at
        FROM help_requests 
        WHERE status != 'Cancelled'
        ORDER BY created_at DESC
        LIMIT 5
      `);
      
      console.log(`🧪 Direct query returned ${result.rows.length} rows`);
      
      const simpleMapped = result.rows.map(row => ({
        id: row.id.toString(),
        title: row.title,
        latitude: parseFloat(row.latitude),
        longitude: parseFloat(row.longitude),
        status: row.status,
        distance: '0.5mi',
        duration: '5min',
        description: 'Test request',
        contact: 'test@berkeley.edu',
        urgencyLevel: 'Medium',
        createdAt: row.created_at,
        authorName: 'Test User',
        helpersCount: 0,
        isCurrentUserHelping: false
      }));
      
      res.json(simpleMapped);
    } else {
      res.json([]);
    }
    
  } catch (error) {
    console.error('❌ Test fetch error:', error);
    res.status(500).json({ error: error.message });
  }
});

// Error handling middleware
app.use((error, req, res, next) => {
  console.error('🚨 Server error:', error);
  console.error('🚨 Stack trace:', error.stack);
  res.status(500).json({ 
    error: 'Internal server error',
    message: error.message,
    timestamp: new Date().toISOString()
  });
});

// 404 handler
app.use((req, res) => {
  console.log('❓ 404 - Endpoint not found:', req.method, req.url);
  res.status(404).json({ 
    error: 'Endpoint not found',
    method: req.method,
    path: req.url
  });
});

// Start server with database initialization
startServer().then(() => {
  app.listen(PORT, () => {
    console.log(`🚀 CalPin Backend running on port ${PORT}`);
    console.log(`🏥 Health check: http://localhost:${PORT}/health`);
    console.log(`🧪 Test endpoint: http://localhost:${PORT}/api/test`);
    console.log(`🔐 Google Client ID configured: ${!!process.env.GOOGLE_CLIENT_ID}`);
    console.log(`🗄️ Database status: ${databaseConnected ? 'Connected' : 'Disconnected (using fallback)'}`);
    console.log(`📊 Ready for user requests`);
  });
});
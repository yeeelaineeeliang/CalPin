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
app.get('/api/user/stats', authenticateToken, async (req, res) => {
  try {
    const userId = req.user.id;
    
    let stats = {
      requestsMade: 0,
      peopleHelped: 0,
      communityPoints: 0,
      thisWeek: 0
    };

    if (databaseConnected) {
      try {
        // Get user's requests
        const requestsResult = await db.pool.query(
          'SELECT COUNT(*) as count FROM help_requests WHERE author_id = $1',
          [userId]
        );
        
        // Get help offers made by user
        const helpResult = await db.pool.query(
          'SELECT COUNT(*) as count FROM help_offers WHERE helper_id = $1',
          [userId]
        );
        
        // Get recent activity (this week)
        const weekAgoResult = await db.pool.query(`
          SELECT COUNT(*) as count FROM help_offers 
          WHERE helper_id = $1 AND created_at > NOW() - INTERVAL '7 days'
        `, [userId]);

        stats = {
          requestsMade: parseInt(requestsResult.rows[0].count),
          peopleHelped: parseInt(helpResult.rows[0].count),
          communityPoints: parseInt(helpResult.rows[0].count) * 10 + parseInt(requestsResult.rows[0].count) * 2,
          thisWeek: parseInt(weekAgoResult.rows[0].count)
        };
        
        console.log('✅ User stats retrieved from database');
      } catch (dbError) {
        console.log('❌ Database stats failed:', dbError.message);
        // Use fallback calculation
      }
    }

    res.json(stats);
  } catch (error) {
    console.error('❌ User stats error:', error);
    res.status(500).json({ error: 'Failed to get user stats' });
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
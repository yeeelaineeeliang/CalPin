// server.js - Enhanced CalPin Backend Server with PostgreSQL
const express = require('express');
const cors = require('cors');
const { OAuth2Client } = require('google-auth-library');
const { initDatabase, db } = require('./database');
require('dotenv').config();

const app = express();
const PORT = process.env.PORT || 3000;

// Initialize database on startup
initDatabase();

// Google OAuth client for token verification
const client = new OAuth2Client(process.env.GOOGLE_CLIENT_ID);

// Enhanced CORS configuration
app.use(cors({
  origin: '*', // Allow all origins for testing
  methods: ['GET', 'POST', 'PUT', 'DELETE', 'OPTIONS'],
  allowedHeaders: ['Content-Type', 'Authorization', 'Accept']
}));

// Debug middleware to log incoming requests
app.use((req, res, next) => {
  console.log(`\n🔍 [${new Date().toISOString()}] ${req.method} ${req.url}`);
  console.log('📋 Headers:', JSON.stringify(req.headers, null, 2));
  console.log('🔗 Content-Type:', req.get('Content-Type'));
  console.log('🔑 Authorization:', req.get('Authorization') ? 'Bearer ' + req.get('Authorization').substring(7, 20) + '...' : 'None');
  next();
});

// Body parsing middleware - CRITICAL ORDER
app.use(express.json({ 
  limit: '10mb',
  type: ['application/json', 'text/plain'] // Accept both content types
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

// Utility function to verify Google token
async function verifyGoogleToken(token) {
  try {
    console.log('🔐 Verifying Google token...');
    const ticket = await client.verifyIdToken({
      idToken: token,
      audience: process.env.GOOGLE_CLIENT_ID,
    });
    const payload = ticket.getPayload();
    
    // Verify it's a Berkeley email
    if (!payload.email.endsWith('@berkeley.edu') && 
        !payload.email.endsWith('@student.berkeley.edu')) {
      throw new Error('Must use Berkeley email');
    }
    
    console.log('✅ Token verified for:', payload.email);
    
    // Upsert user in database
    const user = await db.upsertUser({
      id: payload.sub,
      email: payload.email,
      name: payload.name
    });
    
    return user;
  } catch (error) {
    console.log('❌ Token verification failed:', error.message);
    throw new Error('Invalid token');
  }
}

// Middleware to authenticate requests
async function authenticateToken(req, res, next) {
  const authHeader = req.headers['authorization'];
  const token = authHeader && authHeader.replace('Bearer ', '');

  console.log('🔐 Auth check - Header present:', !!authHeader);
  console.log('🔐 Auth check - Token extracted:', !!token);

  if (!token) {
    console.log('❌ No token provided');
    return res.status(401).json({ error: 'Access token required' });
  }

  try {
    const user = await verifyGoogleToken(token);
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

// Health check
app.get('/health', async (req, res) => {
  console.log('🏥 Health check requested');
  try {
    const requests = await db.getActiveRequests();
    res.json({ 
      status: 'healthy', 
      timestamp: new Date().toISOString(),
      requests_count: requests.length,
      environment: process.env.NODE_ENV || 'development',
      database: 'connected'
    });
  } catch (error) {
    console.error('❌ Health check failed:', error);
    res.status(500).json({
      status: 'unhealthy',
      error: 'Database connection failed',
      timestamp: new Date().toISOString()
    });
  }
});

// GET /api/fetch - Retrieve all help requests
app.get('/api/fetch', authenticateToken, async (req, res) => {
  try {
    console.log('📥 Fetching requests for user:', req.user.email);
    
    const requests = await db.getActiveRequests();

    // Calculate distances if user location provided
    const userLat = parseFloat(req.query.lat);
    const userLon = parseFloat(req.query.lon);
    
    let responseRequests = requests;
    
    if (userLat && userLon) {
      console.log('📍 Calculating distances from user location:', { userLat, userLon });
      responseRequests = requests.map(request => ({
        ...request,
        distance: calculateDistance(userLat, userLon, request.latitude, request.longitude).toFixed(1) + 'mi',
        duration: Math.ceil(calculateDistance(userLat, userLon, request.latitude, request.longitude) * 15) + 'min'
      }));
    } else {
      // Default distance/duration if no user location
      responseRequests = requests.map(request => ({
        ...request,
        distance: '0.5mi',
        duration: '5min'
      }));
    }

    console.log('✅ Returning', responseRequests.length, 'active requests from database');
    res.json(responseRequests);
  } catch (error) {
    console.error('❌ Fetch error:', error);
    res.status(500).json({ error: 'Failed to fetch requests' });
  }
});

// POST /api/create - Create a new help request
app.post('/api/create', authenticateToken, async (req, res) => {
  try {
    console.log('\n🔧 === CREATE REQUEST DEBUG ===');
    console.log('📨 Request received from:', req.user.email);
    console.log('📦 Body received:', JSON.stringify(req.body, null, 2));
    
    // Handle both direct object and nested object structures
    let requestData = req.body;
    
    // Check if body is wrapped in another object
    if (req.body && typeof req.body === 'object' && Object.keys(req.body).length === 1) {
      const firstKey = Object.keys(req.body)[0];
      if (typeof req.body[firstKey] === 'object') {
        console.log('📦 Detected wrapped data, unwrapping...');
        requestData = req.body[firstKey];
      }
    }
    
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
    console.log('  - urgencyLevel:', urgencyLevel);
    console.log('  - coordinates:', latitude, longitude);

    // Validation
    if (!title || !description || !address || !contact) {
      console.log('❌ Validation failed - missing required fields');
      return res.status(400).json({ 
        error: 'Missing required fields: title, description, address, contact',
        received: {
          title: !!title,
          description: !!description,
          address: !!address,
          contact: !!contact
        }
      });
    }

    if (!latitude || !longitude || isNaN(latitude) || isNaN(longitude)) {
      console.log('❌ Validation failed - invalid coordinates');
      return res.status(400).json({ 
        error: 'Invalid location coordinates',
        received: { latitude, longitude }
      });
    }

    // Validate urgency level
    const validUrgencyLevels = ['Low', 'Medium', 'High', 'Urgent'];
    if (!validUrgencyLevels.includes(urgencyLevel)) {
      console.log('❌ Validation failed - invalid urgency level');
      return res.status(400).json({ 
        error: 'Invalid urgency level. Must be: Low, Medium, High, or Urgent',
        received: urgencyLevel
      });
    }

    // Create request in database
    const newRequest = await db.createRequest({
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
    console.log('🔧 === END CREATE REQUEST DEBUG ===\n');

    res.status(201).json({
      message: 'Request created successfully',
      request: {
        ...newRequest,
        id: newRequest.id.toString(),
        helpersCount: 0,
        helpers: []
      }
    });

  } catch (error) {
    console.error('❌ Create error:', error);
    res.status(500).json({ 
      error: 'Failed to create request',
      details: error.message 
    });
  }
});

// POST /api/requests/:id/offer-help - Offer help for a request
app.post('/api/requests/:id/offer-help', authenticateToken, async (req, res) => {
  try {
    const requestId = parseInt(req.params.id);
    const userId = req.user.id;

    console.log('🤝 Offering help - Request ID:', requestId, 'User:', req.user.email);

    // Check if request exists and user isn't the author
    const requests = await db.getActiveRequests();
    const request = requests.find(r => r.id === requestId.toString());
    
    if (!request) {
      return res.status(404).json({ error: 'Request not found' });
    }

    if (request.authorId === userId) {
      return res.status(400).json({ error: 'Cannot offer help on your own request' });
    }

    await db.offerHelp(requestId, userId, req.user.name);

    console.log('✅ Help offered successfully by:', req.user.name);

    res.json({ message: 'Help offered successfully' });

  } catch (error) {
    if (error.code === '23505') { // Unique constraint violation
      return res.status(400).json({ error: 'You are already helping with this request' });
    }
    console.error('❌ Offer help error:', error);
    res.status(500).json({ error: 'Failed to offer help' });
  }
});

// PUT /api/requests/:id/status - Update request status
app.put('/api/requests/:id/status', authenticateToken, async (req, res) => {
  try {
    const requestId = parseInt(req.params.id);
    const { status } = req.body;
    const userId = req.user.id;

    console.log('📝 Updating status - Request ID:', requestId, 'New status:', status);

    const validStatuses = ['Open', 'In Progress', 'Completed', 'Cancelled'];
    if (!validStatuses.includes(status)) {
      return res.status(400).json({ error: 'Invalid status' });
    }

    const updatedRequest = await db.updateRequestStatus(requestId, status, userId);
    
    if (!updatedRequest) {
      return res.status(404).json({ error: 'Request not found or unauthorized' });
    }

    console.log('✅ Status updated successfully to:', status);

    res.json({
      message: 'Status updated successfully',
      request: updatedRequest
    });

  } catch (error) {
    console.error('❌ Status update error:', error);
    res.status(500).json({ error: 'Failed to update status' });
  }
});

// GET /api/user/stats - Get user statistics
app.get('/api/user/stats', authenticateToken, async (req, res) => {
  try {
    const stats = await db.getUserStats(req.user.id);
    console.log('📊 User stats for:', req.user.email, stats);
    res.json(stats);
  } catch (error) {
    console.error('❌ Stats error:', error);
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
    headers: req.headers
  });
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

// Start server
app.listen(PORT, () => {
  console.log(`🚀 CalPin Backend running on port ${PORT}`);
  console.log(`🏥 Health check: http://localhost:${PORT}/health`);
  console.log(`🧪 Test endpoint: http://localhost:${PORT}/api/test`);
  console.log(`🔑 Google Client ID configured: ${!!process.env.GOOGLE_CLIENT_ID}`);
  console.log(`💾 Database: PostgreSQL connected`);
});
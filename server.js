// Add these endpoints to your server.js file

// GET /api/requests/:id/helper-status - Check if current user is helping with this request
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

// REPLACE your existing GET /api/fetch endpoint with this enhanced version:
app.get('/api/fetch', authenticateToken, async (req, res) => {
  try {
    console.log('📥 Fetching requests for user:', req.user.email);
    
    let activeRequests = [];
    
    if (databaseConnected) {
      try {
        console.log('🗄️ Fetching from database...');
        activeRequests = await db.getActiveRequests();
        console.log(`✅ Found ${activeRequests.length} requests in database`);
        
        // Check which requests the current user is helping with
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
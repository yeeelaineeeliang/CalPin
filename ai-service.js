const Anthropic = require('@anthropic-ai/sdk');

class AIService {
  constructor() {
    this.client = new Anthropic({
      apiKey: process.env.ANTHROPIC_API_KEY,
    });
    
    // Configuration
    this.model = 'claude-sonnet-4-20250514'; 
    this.maxTokens = 1024;
    
    // Categories for request classification
    this.categories = [
      { id: 'academic', 
        name: 'Academic', 
        icon: '📚',     
        keywords: ['homework', 'study', 'exam', 'assignment', 'tutor', 'class', 'calculus', 'physics', 'chemistry', 'math', 'biology', 'cs','essay', 'paper', 'project', 'lab', 'research', 'thesis',
        'midterm', 'final', 'quiz', 'lecture', 'notes', 'textbook','course', 'subject', 'learning', 'education', 'academic', 'application']
      },
      { id: 'technical', 
        name: 'Technical', 
        icon: '💻', 
        keywords: ['code', 'computer', 'software', 'debug', 'programming', 'website', 'app', 'laptop', 'python', 'java', 'javascript', 'git', 'github', 'error', 'bug',
      'install', 'setup', 'configure', 'tech', 'device', 'phone', 'wifi','network', 'server', 'database', 'api', 'terminal', 'compile']
      },
      { id: 'social', name: 'Social', icon: '🤝', keywords: ['friend', 'talk', 'lonely', 'meet', 'hangout', 'connect', 'social', 'party'] },
      { id: 'transportation', name: 'Transportation', icon: '🚗', keywords: ['ride', 'drive', 'car', 'bus', 'transport', 'airport', 'pickup', 'drop', 'carpool'] },
      { id: 'moving', name: 'Moving/Carrying', icon: '📦', keywords: ['move', 'carry', 'lift', 'furniture', 'heavy', 'box', 'load'] },
      { id: 'food', name: 'Foodie', icon: '🍕', keywords: ['food', 'meal', 'hungry', 'eat', 'restaurant', 'lunch', 'dinner', 'cook'] },
      { id: 'health', name: 'Health & Wellness', icon: '🏥', keywords: ['sick', 'doctor', 'medicine', 'health', 'hospital', 'injury', 'wellness', 'mental'] },
      { id: 'emergency', name: 'Emergency', icon: '🚨', keywords: ['urgent', 'emergency', 'asap', 'help', 'critical', 'immediately', 'now'] },
      { id: 'other', name: 'Other', icon: '📌', keywords: [] }
    ];
  }

  /**
   * Categorize a help request using Claude
   * @param {string} title - Request title
   * @param {string} description - Request description
   * @param {string} urgencyLevel - User-selected urgency level
   * @returns {Promise<Object>} Category analysis
   */
  async categorizeRequest(title, description, urgencyLevel) {
  try {
    const prompt = `You are analyzing a help request from a UC Berkeley student. Categorize this request and provide helpful insights.

Request Title: ${title}
Description: ${description}
User-Selected Urgency: ${urgencyLevel}

Available categories:
${this.categories.map(c => `- ${c.name} (${c.id}): For requests about ${c.keywords.slice(0, 5).join(', ')}`).join('\n')}

Analyze this request and respond with a JSON object containing:
1. "category": The most appropriate category ID from the list above
2. "suggestedTitle": A clearer, more concise title (if needed, otherwise same as original)
3. "estimatedTime": Estimated time needed in minutes (just the number)
4. "detectedUrgency": Your assessment of true urgency: "Low", "Medium", "High", or "Urgent"
5. "tags": Array of 2-4 relevant tags
6. "safetyCheck": "safe" or "flagged" - flag if request seems inappropriate, unsafe, or violates community guidelines
7. "safetyReason": If flagged, explain why briefly

CRITICAL: Respond ONLY with valid JSON, no markdown code blocks or other text.`;

    const message = await this.client.messages.create({
      model: this.model,
      max_tokens: this.maxTokens,
      messages: [{
        role: 'user',
        content: prompt
      }]
    });

    let responseText = message.content[0].text.trim();
    
    // Remove markdown code blocks if present
    if (responseText.startsWith('```json')) {
      responseText = responseText.replace(/^```json\s*/, '').replace(/\s*```$/, '');
    } else if (responseText.startsWith('```')) {
      responseText = responseText.replace(/^```\s*/, '').replace(/\s*```$/, '');
    }

    const analysis = JSON.parse(responseText);

    // Add category metadata
    const categoryInfo = this.categories.find(c => c.id === analysis.category);
    analysis.categoryIcon = categoryInfo?.icon || '📌';
    analysis.categoryName = categoryInfo?.name || 'Other';

    console.log('Request categorized:', analysis);
    return analysis;

  } catch (error) {
    console.error('AI categorization error:', error.message);
    return this.fallbackCategorization(title, description, urgencyLevel);
  }
}

  /**
   * Fallback categorization using simple keyword matching
   */
  fallbackCategorization(title, description, urgencyLevel) {
    const text = `${title} ${description}`.toLowerCase();
    
    let matchedCategory = this.categories[this.categories.length - 1]; // Default to 'other'
    let maxMatches = 0;

    for (const category of this.categories) {
      if (category.id === 'other') continue;
      
      const matches = category.keywords.filter(keyword => 
        text.includes(keyword.toLowerCase())
      ).length;

      if (matches > maxMatches) {
        maxMatches = matches;
        matchedCategory = category;
      }
    }

    return {
      category: matchedCategory.id,
      categoryIcon: matchedCategory.icon,
      categoryName: matchedCategory.name,
      suggestedTitle: title,
      estimatedTime: 30,
      detectedUrgency: urgencyLevel,
      tags: [matchedCategory.name],
      safetyCheck: 'safe',
      safetyReason: null
    };
  }

  /**
 * Enhanced safety check with specific sensitive word detection
 * @param {string} title - Request title
 * @param {string} description - Request description
 * @returns {Promise<Object>} Safety analysis with detailed reason
 */
  async performSafetyCheck(title, description) {
    // First: Quick keyword pre-filter
    const SENSITIVE_KEYWORDS = {
      'personal_info': ['ssn', 'social security', 'credit card', 'bank account', 'password', 'address', 'phone number'],
      'romantic': ['hook up', 'sex'],
      'substances': ['drugs', 'adderall', 'xanax', 'pills'],
      'academic_dishonesty': ['exam answers', 'do my homework', 'write my paper', 'take my exam', 'cheat', 'plagiarize'],
      'financial': ['loan', 'borrow money', 'lend money', 'pay me', 'venmo', 'cash app'],
      'illegal': ['fake id', 'steal', 'break in', 'hack']
    };

    const text = `${title} ${description}`.toLowerCase();
    
    // Check for sensitive keywords
    for (const [category, keywords] of Object.entries(SENSITIVE_KEYWORDS)) {
      for (const keyword of keywords) {
        if (text.includes(keyword)) {
          return {
            isSafe: false,
            flaggedCategory: category,
            reason: this.getSafetyMessage(category),
            keyword: keyword
          };
        }
      }
    }

    // Second: AI-powered context check (for nuanced cases)
    try {
      const prompt = `Analyze this help request for safety and appropriateness for a student support app.

  Title: ${title}
  Description: ${description}

  Check for:
  1. Personal identifying information (SSN, addresses, private data)
  2. Substance-related requests (alcohol, drugs, prescriptions)
  3. Academic dishonesty (cheating, selling answers)
  4. Financial transactions (loans, money requests)
  5. Illegal activities
  6. Harassment or inappropriate content

  Respond with JSON:
  {
    "isSafe": true/false,
    "flaggedCategory": "category_name" or null,
    "reason": "Brief explanation for user (1 sentence)" or null,
    "severity": "low|medium|high" or null
  }

  If safe, return { "isSafe": true, "flaggedCategory": null, "reason": null, "severity": null }
  Respond ONLY with valid JSON.`;

      const message = await this.client.messages.create({
        model: this.model,
        max_tokens: 200,
        messages: [{
          role: 'user',
          content: prompt
        }]
      });

      const result = JSON.parse(message.content[0].text);
      
      if (!result.isSafe) {
        return {
          isSafe: false,
          flaggedCategory: result.flaggedCategory,
          reason: result.reason || 'This request violates our community guidelines.',
          severity: result.severity || 'medium'
        };
      }

      return { isSafe: true, flaggedCategory: null, reason: null };

    } catch (error) {
      console.error('AI safety check error:', error.message);
      // On error, be conservative - use keyword results only
      return { isSafe: true, flaggedCategory: null, reason: null };
    }
  }

  /**
   * Get user-friendly safety message for flagged category
   */
  getSafetyMessage(category) {
    const messages = {
      'personal_info': 'For your safety, please don\'t share personal information like addresses, SSN, or bank details.',
      'substances': 'Requests involving alcohol, drugs, or prescriptions aren\'t allowed. Contact Tang Center for health needs.',
      'academic_dishonesty': 'Academic integrity is important. We can\'t help with cheating. Visit the Student Learning Center for study help.',
      'mental_health_crisis': 'This sounds serious. Please contact CAPS (510-642-9494) or Crisis Line (855-817-5667) for professional help.',
      'financial': 'For safety reasons, we don\'t allow money lending or financial transactions between students.',
      'illegal': 'This request appears to involve illegal activity and cannot be posted.'
    };
    
    return messages[category] || 'This request violates our community guidelines.';
  }

  /**
   * Improve request title and description using Claude
   * @param {string} title - Original title
   * @param {string} description - Original description
   * @returns {Promise<Object>} Improved request
   */
  async improveRequest(title, description) {
  try {
    const prompt = `You are helping a UC Berkeley student write a clearer help request. Make their request more effective while keeping their original intent.

Original Title: ${title}
Original Description: ${description}

Improve this request by:
1. Making the title clear and specific (max 50 characters)
2. Organizing the description with clear details (max 50 words)
3. Keeping the student's voice and urgency
4. Adding any helpful context or questions that helpers might need

CRITICAL: Respond with ONLY valid JSON. Do not use markdown code blocks. Do not add any text before or after the JSON.

{
  "improvedTitle": "clear concise title",
  "improvedDescription": "well-organized description",
  "suggestions": ["tip 1", "tip 2"]
}`;

    const message = await this.client.messages.create({
      model: this.model,
      max_tokens: this.maxTokens,
      messages: [{
        role: 'user',
        content: prompt
      }]
    });

    let responseText = message.content[0].text.trim();
    
    // Remove markdown code blocks if present
    if (responseText.startsWith('```json')) {
      responseText = responseText.replace(/^```json\s*/, '').replace(/\s*```$/, '');
    } else if (responseText.startsWith('```')) {
      responseText = responseText.replace(/^```\s*/, '').replace(/\s*```$/, '');
    }
    
    const result = JSON.parse(responseText);
    
    return {
      improvedTitle: result.improvedTitle || title,
      improvedDescription: result.improvedDescription || description,
      suggestions: result.suggestions || []
    };

  } catch (error) {
    console.error('AI improvement error:', error.message);
    return {
      improvedTitle: title,
      improvedDescription: description,
      suggestions: ['Be specific about what you need', 'Include location details', 'Mention time constraints']
    };
  }
}

  /**
   * Generate smart notification message for potential helpers
   * @param {Object} request - The help request
   * @param {Object} helperProfile - Helper's profile/history
   * @returns {Promise<string>} Personalized notification message
   */
  async generateNotification(request, helperProfile) {
    try {
      const prompt = `Create a brief, friendly push notification to ${helperProfile.name} about a help request.

Request: ${request.title}
Category: ${request.category}
Distance: ${request.distance || 'nearby'}
Helper's past helps: ${helperProfile.helpCount || 0}
Helper's specialties: ${helperProfile.categories?.join(', ') || 'general'}

Write a compelling 1-sentence notification (max 100 chars) that:
- Is friendly and specific
- Mentions why they'd be good for this
- Creates urgency if appropriate

Return ONLY the notification text, nothing else.`;

      const message = await this.client.messages.create({
        model: this.model,
        max_tokens: 150,
        messages: [{
          role: 'user',
          content: prompt
        }]
      });

      return message.content[0].text.trim().replace(/^"|"$/g, '');

    } catch (error) {
      console.error('AI notification error:', error.message);
      return `${request.title} - ${request.distance || 'nearby'}`;
    }
  }

  /**
   * AI Helper Assistant - Answer questions about requests or helping
   * @param {string} userMessage - User's question
   * @param {Object} context - Context about user, requests, etc.
   * @returns {Promise<string>} AI response
   */
  async chatAssistant(userMessage, context = {}) {
    try {
      const systemPrompt = `You are CalPin Assistant, a helpful AI for UC Berkeley students using the CalPin app to help each other.

Context:
- User: ${context.userName || 'Student'}
- They've helped ${context.helpCount || 0} students
- They've made ${context.requestCount || 0} requests

You help students:
1. Write better help requests
2. Understand how to help effectively
3. Find campus resources
4. Navigate the app

Be friendly, concise (2-3 sentences max), and Berkeley-spirited. If they're in crisis, direct them to campus resources: Tang Center (510-642-2000), CAPS (510-642-9494), or UCPD (510-642-6760).`;

      const message = await this.client.messages.create({
        model: this.model,
        max_tokens: 300,
        system: systemPrompt,
        messages: [{
          role: 'user',
          content: userMessage
        }]
      });

      return message.content[0].text.trim();

    } catch (error) {
      console.error('AI chat error:', error.message);
      return "I'm having trouble connecting right now. Try asking again in a moment!";
    }
  }

  /**
   * Analyze if multiple requests might be duplicates
   * @param {Array} requests - Array of requests to compare
   * @returns {Promise<Array>} Groups of potential duplicates
   */
  async detectDuplicates(requests) {
    if (requests.length < 2) return [];

    try {
      const requestSummaries = requests.map(r => 
        `ID ${r.id}: ${r.title} - ${r.description.substring(0, 100)}`
      ).join('\n');

      const prompt = `Analyze these help requests and identify potential duplicates or very similar requests:

${requestSummaries}

Return JSON array of duplicate groups:
[
  {
    "requestIds": [1, 3],
    "reason": "Both asking for calculus homework help",
    "confidence": "high"
  }
]

Only include groups with 2+ requests. Return empty array [] if no duplicates. Respond with ONLY valid JSON.`;

      const message = await this.client.messages.create({
        model: this.model,
        max_tokens: 500,
        messages: [{
          role: 'user',
          content: prompt
        }]
      });

      return JSON.parse(message.content[0].text);

    } catch (error) {
      console.error('AI duplicate detection error:', error.message);
      return [];
    }
  }

  /**
   * Generate weekly impact summary for user
   * @param {Object} userStats - User's statistics
   * @param {Array} activities - Recent activities
   * @returns {Promise<string>} Motivational summary
   */
  async generateWeeklySummary(userStats, activities) {
    try {
      const prompt = `Create an inspiring weekly summary for a Berkeley student helper.

Stats this week:
- Helped ${userStats.thisWeek || 0} students
- Total community points: ${userStats.communityPoints || 0}
- Current streak: ${userStats.streak || 0} weeks

Recent activities:
${activities.slice(0, 5).map(a => `- ${a.activityType}: ${a.requestTitle}`).join('\n')}

Write a warm, motivating 2-3 sentence summary celebrating their impact. Be specific about what they did. End with encouragement.

Return ONLY the summary text.`;

      const message = await this.client.messages.create({
        model: this.model,
        max_tokens: 200,
        messages: [{
          role: 'user',
          content: prompt
        }]
      });

      return message.content[0].text.trim();

    } catch (error) {
      console.error('AI summary error:', error.message);
      return `You've helped ${userStats.thisWeek || 0} fellow Bears this week! Keep making campus better! 🐻💙`;
    }
  }
}

module.exports = new AIService();
# 📱 Multi-Platform Message Bot - Complete Implementation Guide

## 🎯 What You're Building

An intelligent message bot that:
- ✅ Reads Instagram DMs automatically
- ✅ Reads Facebook Messenger messages
- ✅ Reads WhatsApp messages
- ✅ Uses Claude AI to generate smart, contextual replies
- ✅ Sends replies back to the same platform
- ✅ Logs all conversations to database
- ✅ Operates 24/7 in Docker

**Cost**: ~$10-50/month (depending on message volume)

---

## 🔐 Step 1: Collect API Credentials

### **A. Meta API (Instagram + Facebook)**

1. Go to: https://developers.facebook.com/
2. Log in with your Meta account
3. Create or select your app
4. Copy these values:
   ```
   App ID: ________________
   App Secret: ________________
   Page ID: ________________
   Page Access Token: ________________ (long-lived)
   Instagram Business Account ID: ________________
   ```

**How to get each:**

- **App ID & Secret**: Settings → Basic
- **Page ID**: Go to your Facebook page → About → Settings
- **Page Access Token**: Tools → Access Token Generator → Select page → Generate
- **Instagram Business Account ID**: Instagram Settings → Connected Apps

### **B. Twilio (WhatsApp - Easiest Option)**

1. Go to: https://www.twilio.com/
2. Sign up or log in
3. Create new project
4. Enable WhatsApp in Console
5. Copy these values:
   ```
   Account SID: ________________
   Auth Token: ________________
   Twilio WhatsApp Number: ________________
   ```

### **C. Claude API (AI Responses)**

1. Go to: https://console.anthropic.com/
2. Log in or create account
3. API Keys section
4. Create new API key
5. Copy:
   ```
   Claude API Key: sk-ant-________________
   ```

---

## 🛠️ Step 2: Set Up n8n Credentials

### **In n8n Settings:**

1. **Login**: http://localhost:5678
2. **Go to**: Settings (bottom-left gear icon)
3. **Click**: "Credentials"
4. **Add each credential**:

#### **Credential 1: Meta API**
```
Name: Meta API Credentials
Type: Meta (if available) or Custom
Fill in:
- App ID
- App Secret
- Page Access Token
- Page ID
```

#### **Credential 2: Claude**
```
Name: Claude API
Type: Anthropic
API Key: sk-ant-...
```

#### **Credential 3: Twilio (optional for WhatsApp)**
```
Name: Twilio Credentials
Type: Twilio
Account SID: AC...
Auth Token: ...
```

---

## 📋 Step 3: Create Instagram/Facebook Workflow

### **Workflow Name**: "Message Bot - Instagram"

### **Node 1: Webhook Trigger**
```
Type: Webhook
HTTP Method: POST
Path: instagram-messages
Authentication: None

🔗 COPY THE WEBHOOK URL
(You'll use this in Meta settings)
```

### **Node 2: Parse Message**
```
Type: Set
Add these keys:

sender_id = {{$json.messaging[0].sender.id}}
message_text = {{$json.messaging[0].message.text}}
platform = "instagram"

(These extract data from Meta's message format)
```

### **Node 3: Generate AI Reply**
```
Type: Anthropic (Claude)
Credential: Claude API

System Prompt:
"You are a professional, friendly customer service bot.
Reply to customer messages helpfully and concisely.
Keep replies to 1-2 sentences maximum.
Be warm and human-like in tone.
If asked about products, provide helpful info.
If you can't help, offer to connect with support."

User Message: {{$json.message_text}}

Temperature: 0.7 (balanced creativity)
Max Tokens: 150
```

### **Node 4: Send Reply**
```
Type: Instagram (or Facebook)
Credential: Meta API Credentials
Action: Send Message

Recipient ID: {{$json.sender_id}}
Message Text: {{$node["Anthropic"].json.response}}
Message Type: Text
```

### **Node 5: Log to Database (Optional)**
```
Type: PostgreSQL
Query:
INSERT INTO messages 
(platform, from_id, message_text, reply_text, created_at)
VALUES 
({{$json.platform}}, 
 {{$json.sender_id}}, 
 {{$json.message_text}}, 
 {{$node["Anthropic"].json.response}}, 
 NOW())
```

---

## 📱 Step 4: Create WhatsApp Workflow

### **Workflow Name**: "Message Bot - WhatsApp"

### **Node 1: Webhook Trigger**
```
Type: Webhook
HTTP Method: POST
Path: whatsapp-messages
Authentication: None

🔗 COPY THIS URL FOR TWILIO
```

### **Node 2: Parse Message**
```
Type: Set

phone = {{$json.messages[0].from}}
message_text = {{$json.messages[0].text.body}}
```

### **Node 3: Generate Reply**
```
Same as Instagram (reuse Claude setup)
```

### **Node 4: Send WhatsApp Reply**
```
Type: Twilio
Credential: Twilio Credentials
Action: Send Message

From: [Your Twilio WhatsApp Number]
To: {{$json.phone}}
Body: {{$node["Anthropic"].json.response}}
Type: WhatsApp
```

---

## ⚙️ Step 5: Register Webhooks

### **In Meta App Dashboard:**

1. Go to: https://developers.facebook.com/apps/YOUR_APP_ID/
2. Messenger → Settings
3. Webhooks:
   ```
   Callback URL: http://YOUR_N8N_URL/webhook/instagram-messages
   Verify Token: n8n_bot_secure_2024
   
   Subscribe to:
   ✓ messages
   ✓ messaging_postbacks
   ```

### **In Twilio Console:**

1. Go to: https://console.twilio.com/
2. WhatsApp Sandbox Settings
3. When a message comes in:
   ```
   POST: http://YOUR_N8N_URL/webhook/whatsapp-messages
   ```

---

## 🧪 Step 6: Testing

### **Test Instagram:**

1. Send a DM to your Instagram business account
2. Check n8n execution (click "Executions" tab)
3. Verify bot reply appears in 1-2 seconds
4. **If it doesn't work**:
   - Check webhook URL in Meta is correct
   - Check credentials are valid
   - Check n8n is running: `docker-compose ps`

### **Test WhatsApp:**

1. Send message to Twilio WhatsApp number
2. Check n8n execution logs
3. Verify reply appears
4. **If it doesn't work**:
   - Verify Twilio credentials
   - Check webhook URL in Twilio
   - Test with curl command

---

## 🚀 Step 7: Activate & Deploy

### **Activate Workflows:**

1. In each workflow, click **"Activate"** button (top-right)
2. Status should show: ✅ Active
3. Webhooks are now listening 24/7

### **Monitor:**

1. Check "Executions" tab regularly
2. Monitor logs for errors
3. Keep API usage under control (set alerts in Claude/Meta)

---

## 📊 Advanced: Add Features

### **Feature 1: Database Logging**

Track all messages:
```sql
CREATE TABLE messages (
  id SERIAL PRIMARY KEY,
  platform VARCHAR(50),
  from_id VARCHAR(100),
  message_text TEXT,
  reply_text TEXT,
  created_at TIMESTAMP DEFAULT NOW()
);
```

### **Feature 2: Sentiment Analysis**

Detect urgency:
```
Node: Code (Execute JavaScript)

if (message.includes("urgent") || 
    message.includes("help") || 
    message.includes("problem")) {
  return { priority: "high" }
} else {
  return { priority: "normal" }
}
```

Then route to different handlers.

### **Feature 3: Human Handoff**

For complex queries:
```
IF message is unclear OR
   Claude confidence < 0.6 OR
   message contains "human"
→ Send to support team (Slack/Email)
ELSE
→ Reply with AI
```

### **Feature 4: Analytics Dashboard**

Query saved messages:
```sql
SELECT 
  DATE(created_at) as date,
  COUNT(*) as total_messages,
  platform,
  AVG(LENGTH(reply_text)) as avg_reply_length
FROM messages
GROUP BY DATE(created_at), platform
ORDER BY date DESC
```

### **Feature 5: Conversation History**

Remember previous messages:
```
Query database for past messages from same user
Pass to Claude: 
"Previous conversation: [history]
New message: {{$json.message_text}}"
```

---

## 🔒 Security Best Practices

```
✅ Store API keys in n8n Credentials (encrypted)
✅ Use webhook paths that are unique/unpredictable
✅ Implement rate limiting (max 10 messages/min per user)
✅ Log all conversations (comply with GDPR)
✅ Validate webhook signatures from Meta/Twilio
✅ Use HTTPS when deploying (not localhost)
✅ Monitor for abuse patterns
✅ Set up alerts for errors
✅ Backup message database weekly
✅ Review logs for suspicious activity
```

---

## 💰 Cost Breakdown

| Service | Free Tier | Per Message |
|---------|-----------|-------------|
| **Meta (Insta/FB)** | Unlimited | Included |
| **Twilio WhatsApp** | 100 msgs | $0.0075 |
| **Claude API** | N/A | $0.003 per 1K tokens |
| **n8n (Docker)** | Unlimited | $0 |
| **PostgreSQL** | Unlimited | $0 |
| **Total/Month** | 100 msgs | ~$10-30 |

---

## 📝 Verification Checklist

Before going live:

- [ ] Meta app created and approved
- [ ] Twilio account set up
- [ ] Claude API key obtained
- [ ] All credentials added to n8n
- [ ] Instagram workflow created and tested
- [ ] WhatsApp workflow created and tested
- [ ] Webhooks registered in Meta and Twilio
- [ ] Test messages sent and replies received
- [ ] Database logging working (if using)
- [ ] Workflows activated
- [ ] Error handling in place
- [ ] Rate limiting configured
- [ ] Monitoring/alerts set up

---

## 🐛 Troubleshooting

| Problem | Solution |
|---------|----------|
| Messages not arriving | Check webhook URL, verify token |
| No reply sent | Verify Claude API key, check message format |
| Wrong reply format | Check JSON parsing in Set node |
| Rate limit errors | Add delay node, implement queue |
| Timeouts | Reduce max tokens, increase timeout |
| Database errors | Check PostgreSQL connection |
| Webhook not working | Test with curl: `curl -X POST http://localhost:5678/webhook/instagram-messages -d '...'` |

---

## 📚 File References

- **Full Setup**: `/Users/adhielesmana/n8n/MULTI_PLATFORM_BOT_SETUP.md`
- **Quick Start**: `/Users/adhielesmana/n8n/QUICK_START_BOT.md`
- **This File**: `/Users/adhielesmana/n8n/BOT_IMPLEMENTATION_SUMMARY.md`

---

## ✨ What's Possible Next

Once this is working:

1. **Analytics Dashboard**: Track message volume, response times
2. **Multi-language Support**: Translate messages before reply
3. **Sentiment Analysis**: Route urgent messages to humans
4. **CRM Integration**: Store conversations in Salesforce/HubSpot
5. **Custom Training**: Fine-tune AI on your response style
6. **Mobile App**: Monitor bot activity from phone
7. **A/B Testing**: Test different response styles
8. **Integration**: Connect to booking, payments, etc.

---

## 🎓 Learning Resources

- **n8n Docs**: https://docs.n8n.io/
- **Meta API**: https://developers.facebook.com/docs/
- **Twilio**: https://www.twilio.com/docs/
- **Claude**: https://docs.anthropic.com/

---

## 🤝 Support

For issues:
1. Check logs in n8n ("Executions" tab)
2. Verify API credentials
3. Test with curl commands
4. Check webhook URLs match
5. Review n8n documentation

---

**Ready to build? Start with Step 1: Collect API Credentials!**


# 🚀 Quick Start: Multi-Platform Bot (5 Minutes)

## Prerequisites

You need these API keys:

1. **Meta Access Token** (for Instagram/Facebook)
   - Get from: https://developers.facebook.com/apps
   - Format: `EAAB...`

2. **Twilio Credentials** (for WhatsApp - easier)
   - Get from: https://www.twilio.com/
   - SID: `AC...`
   - Token: `auth_token`

3. **Claude API Key** (for AI replies)
   - Get from: https://console.anthropic.com/
   - Format: `sk-ant-...`

---

## Quick Setup in n8n

### **Step 1: Create First Workflow**

```
Name: "Message Bot - Instagram"
Description: "Auto-reply to Instagram DMs with AI"
```

### **Step 2: Add Webhook Trigger**

1. Click "Add first step..."
2. Search: `webhook`
3. Select: **Webhook**
4. **Configure**:
   - Method: POST
   - Path: `instagram`
5. **Copy URL** (you'll need this)

### **Step 3: Parse Incoming Message**

1. Click "+" after webhook
2. Search: `set`
3. Select: **Set**
4. **Add keys**:
   ```
   sender_id = {{$json.messaging[0].sender.id}}
   message = {{$json.messaging[0].message.text}}
   ```

### **Step 4: Generate AI Reply**

1. Click "+" 
2. Search: `anthropic` (or `openai`)
3. Select: **Anthropic** or **OpenAI**
4. **Create Credential**:
   - Click: "Create new credential"
   - API Key: Paste your Claude key
   - Save
5. **Configure**:
   ```
   System Prompt: "You are a friendly customer service bot. 
                   Reply helpfully and briefly (max 2 sentences)."
   
   User Message: {{$json.message}}
   
   Temperature: 0.7
   ```

### **Step 5: Send Reply to Instagram**

1. Click "+"
2. Search: `instagram`
3. Select: **Instagram**
4. **Create Credential**:
   - Meta Access Token: Paste your token
   - Page ID: Your page ID
5. **Configure**:
   ```
   Action: Send Message
   Recipient ID: {{$json.sender_id}}
   Message: {{$node["Claude"].json.response}}
   ```

### **Step 6: Test**

1. Click **"Test"** button
2. Send test message to Instagram DM
3. Check execution logs
4. Verify reply appears

---

## Add WhatsApp (2 Minutes)

### **Create Second Workflow**

```
Name: "Message Bot - WhatsApp"
```

1. **Webhook** → Path: `whatsapp`
2. **Set** → Extract:
   ```
   phone = {{$json.messages[0].from}}
   message = {{$json.messages[0].text.body}}
   ```
3. **Claude** → (reuse same setup)
4. **Twilio** → Send WhatsApp
   ```
   From: Your Twilio number
   To: {{$json.phone}}
   Message: {{$node["Claude"].json.response}}
   ```
5. **Test** and **Activate**

---

## Webhook URLs to Register

### **In Meta Dashboard**:
```
https://your-domain/webhook/instagram
```

### **In Twilio Dashboard**:
```
https://your-domain/webhook/whatsapp
```

---

## Test Messages

**To Instagram**:
- Send DM to your page
- Bot should reply in 1-2 seconds

**To WhatsApp**:
- Send message to Twilio number
- Bot should reply in 1-2 seconds

---

## What to Do If It Doesn't Work

1. **Check webhook URL**: Copy from n8n, paste in Meta/Twilio
2. **Check credentials**: Verify API keys are correct
3. **Check logs**: Click "Executions" tab
4. **Test manually**: Send curl request:
   ```bash
   curl -X POST http://localhost:5678/webhook/instagram \
     -H "Content-Type: application/json" \
     -d '{"messaging":[{"sender":{"id":"123"},"message":{"text":"hello"}}]}'
   ```

---

## That's It!

Your bot is now live and will:
✅ Read messages from Instagram DMs
✅ Read messages from WhatsApp
✅ Use Claude AI to generate smart replies
✅ Send replies back automatically

Next, add more features:
- Database logging
- Sentiment analysis
- Human handoff
- Analytics dashboard

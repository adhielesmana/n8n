# 🤖 Multi-Platform Message Reply Bot (Instagram, Facebook, WhatsApp)

## Overview
This app automatically reads messages from Instagram DMs, Facebook Messenger, and WhatsApp, uses AI to generate intelligent replies, and sends responses back to each platform.

---

## Architecture

```
┌─────────────────────────────────────────────────────────┐
│           INCOMING MESSAGES (Webhooks)                 │
├─────────────┬──────────────────┬───────────────────────┤
│             │                  │                       │
▼             ▼                  ▼                       ▼
Instagram   Facebook           WhatsApp              Other
Webhook     Webhook            Webhook               Services
│             │                  │                       │
└─────────────┴──────────────────┴───────────────────────┘
              │
              ▼
    ┌──────────────────┐
    │  Parse Message   │
    │  (From, Text)    │
    └────────┬─────────┘
             │
             ▼
    ┌──────────────────────────┐
    │  AI Generation (Claude)  │
    │  Generate Smart Reply    │
    └────────┬─────────────────┘
             │
             ▼
    ┌──────────────────────────┐
    │  Route by Platform       │
    │  Instagram/FB/WhatsApp   │
    └──┬───────────┬───────────┘
       │           │
       ▼           ▼
    Send to    Send to
    Original   Original
    Platform   Platform
```

---

## Part 1: Get API Credentials

### 1️⃣ **Instagram & Facebook (Meta Business Account)**

#### Prerequisites:
- Facebook Business Account
- Instagram Business Account connected to Facebook
- Meta App with permissions

#### Steps:

1. **Create Meta App**:
   - Go to: https://developers.facebook.com/apps
   - Click "Create App"
   - Choose "Business" type
   - Name: "n8n Message Bot"
   - Purpose: "Messaging"

2. **Get Access Token**:
   - In app dashboard → Settings → Basic
   - Copy: `App ID` and `App Secret`
   - Go to: Tools → Access Token Generator
   - Select `instagram_manage_messages` permission
   - Get: `Page Access Token` (long-lived)
   - Format: `EAAB...` (save this)

3. **Configure Webhook**:
   - In app dashboard → Messenger → Settings
   - Webhook URL: `http://YOUR_N8N_URL/webhook/instagram-facebook`
   - Verify Token: `n8n_meta_bot_2024` (set in n8n)
   - Subscribe to: `messages`, `messaging_postbacks`

4. **Get Page ID**:
   - Go to: https://www.facebook.com/YOUR_PAGE/settings/basic
   - Page ID appears in URL or settings
   - Save: `PAGE_ID` and `INSTAGRAM_BUSINESS_ACCOUNT_ID`

### 2️⃣ **WhatsApp Business API**

#### Options:
- **Official WhatsApp Business API** (Most reliable)
- **Twilio WhatsApp** (Easier setup)
- **Meta WhatsApp Business** (Same as Facebook)

#### Using Meta WhatsApp (Same as above):

1. **Get WhatsApp Business Account ID**:
   - https://www.meta.com/en/business/tools/whatsapp-business/
   - Create/link WhatsApp Business Account
   - Get: `WHATSAPP_BUSINESS_ACCOUNT_ID`

2. **Phone Number ID**:
   - WhatsApp settings
   - Get: `PHONE_NUMBER_ID` (for sending messages)

3. **Access Token**:
   - Same as Facebook above

#### Using Twilio (Alternative, Easier):

1. Go to: https://www.twilio.com/
2. Sign up → Create account
3. Get: `Account SID` and `Auth Token`
4. Enable: WhatsApp in Console
5. Get: Twilio WhatsApp number

### 3️⃣ **AI Provider (Claude or OpenAI)**

- **Claude**: https://console.anthropic.com/
  - Create API key: `sk-ant-...`
  - Save for n8n

- **OpenAI**: https://platform.openai.com/api-keys
  - Create secret key: `sk-...`
  - Save for n8n

---

## Part 2: n8n Workflow Setup

### **Workflow 1: Instagram + Facebook Messages**

#### Step 1: Create Webhook Trigger

1. **In n8n**, click "Add first step"
2. **Search**: `webhook`
3. **Select**: Webhook (Trigger)
4. **Configure**:
   ```
   Method: POST
   Path: instagram-facebook
   Authentication: None (for now)
   ✓ Copy: Webhook URL
   ```
5. **Paste URL** in Meta App webhook settings

#### Step 2: Add AI Response Generator

1. **Click "+" after webhook**
2. **Search**: `anthropic` or `openai`
3. **Select**: Claude/OpenAI
4. **Credentials**: Create new with API key
5. **Configure**:
   ```
   System Prompt:
   "You are a helpful customer service bot. 
    Reply to messages professionally and friendly.
    Keep replies short (max 2 sentences).
    If you need clarification, ask politely."
   
   User Message:
   "Message from {{$json.messaging[0].message.text}}"
   
   Temperature: 0.7
   Max Tokens: 150
   ```

#### Step 3: Parse Message Details

1. **Add "Set" node** (before AI):
   ```
   Extract message details:
   
   from_id = {{$json.messaging[0].sender.id}}
   message_text = {{$json.messaging[0].message.text}}
   platform = "instagram"
   ```

#### Step 4: Send Reply Back

1. **Click "+" after Claude**
2. **Search**: `instagram` or `facebook`
3. **Select**: "Instagram" or "Facebook"
4. **Action**: Send Message
5. **Configure**:
   ```
   Credential: Meta Access Token
   Recipient ID: {{$json.from_id}}
   Message Text: {{$node["Claude"].json.response}}
   Message Type: Text
   ```

---

### **Workflow 2: WhatsApp Messages**

#### Similar Setup:

1. **Webhook Trigger** (separate):
   ```
   Path: whatsapp
   ```

2. **AI Response** (same Claude node)

3. **Send Reply**:
   - If using Meta: Select WhatsApp action
   - If using Twilio: Select Twilio SMS/WhatsApp
   - Phone Number: {{$json.from_phone}}
   - Message: {{$node["Claude"].json.response}}

---

## Part 3: Complete Workflow JSON

```json
{
  "name": "Multi-Platform Message Bot",
  "nodes": [
    {
      "name": "Instagram/Facebook Webhook",
      "type": "n8n-nodes-base.webhook",
      "webhook_path": "instagram-facebook",
      "http_method": "POST"
    },
    {
      "name": "Parse Message",
      "type": "n8n-nodes-base.set",
      "node_config": {
        "from_id": "={{$json.messaging[0].sender.id}}",
        "message_text": "={{$json.messaging[0].message.text}}",
        "platform": "=\"instagram\""
      }
    },
    {
      "name": "Generate Reply (Claude)",
      "type": "n8n-nodes-anthropic.anthropic",
      "system_prompt": "You are a helpful customer service bot...",
      "user_message": "={{$json.message_text}}"
    },
    {
      "name": "Send to Instagram",
      "type": "n8n-nodes-base.instagram",
      "action": "sendMessage",
      "recipient_id": "={{$json.from_id}}",
      "message": "={{$node['Generate Reply (Claude)'].json.response}}"
    },
    {
      "name": "WhatsApp Webhook",
      "type": "n8n-nodes-base.webhook",
      "webhook_path": "whatsapp",
      "http_method": "POST"
    },
    {
      "name": "Parse WhatsApp",
      "type": "n8n-nodes-base.set",
      "node_config": {
        "from_phone": "={{$json.messages[0].from}}",
        "message_text": "={{$json.messages[0].text.body}}"
      }
    },
    {
      "name": "Send to WhatsApp",
      "type": "n8n-nodes-base.twilio",
      "action": "sendMessage",
      "to_number": "={{$json.from_phone}}",
      "message": "={{$node['Generate Reply (Claude)'].json.response}}"
    }
  ]
}
```

---

## Part 4: Detailed Configuration

### **Instagram/Facebook Setup in n8n**

#### Create Credentials:

1. **Go to**: n8n Settings → Add Credential
2. **Type**: Meta (Instagram/Facebook)
3. **Fill**:
   ```
   Credential Name: Meta API
   Access Token: EAAB... (from Meta app)
   Page ID: 123456789
   ```
4. **Save**

#### Configure Webhook:

1. In **webhook node** → Authentication tab
   - Set: `Verify Token: n8n_meta_bot_2024`
   - In Meta app webhook settings, enter same verify token

2. **Test webhook**:
   ```bash
   curl -X POST http://localhost:5678/webhook/instagram-facebook \
     -H "Content-Type: application/json" \
     -d '{"messaging":[{"sender":{"id":"123"},"message":{"text":"Hello"}}]}'
   ```

### **WhatsApp Setup in n8n**

#### Option A: Meta WhatsApp (If using Meta)

```
Same as Instagram/Facebook
But use WhatsApp Business Account ID
And Phone Number ID for sending
```

#### Option B: Twilio WhatsApp

1. **Create Credential**:
   - Type: Twilio
   - Account SID: (from Twilio)
   - Auth Token: (from Twilio)

2. **Configure node**:
   ```
   From: Your Twilio WhatsApp number
   To: {{$json.from_phone}}
   Message: {{$node["Claude"].json.response}}
   ```

3. **Get Twilio webhook**:
   ```
   Webhook URL: http://YOUR_N8N_URL/webhook/whatsapp
   Method: POST
   ```

### **AI Configuration**

#### Claude Settings:

```
Model: claude-3-5-sonnet-20241022 (latest)
Temperature: 0.7 (balanced, creative but coherent)
Max Tokens: 500 (for detailed replies)

System Prompt Options:

# Customer Service
"You are a professional customer service representative.
Help customers with their inquiries.
Be friendly, concise, and helpful.
If you don't know, offer to connect them with support."

# Sales Support
"You are a sales assistant.
Answer product questions and guide customers.
Always be positive and helpful.
Suggest relevant products when appropriate."

# Tech Support
"You are a technical support specialist.
Help users solve technical issues.
Provide step-by-step guidance.
Be patient and clear in explanations."

# General Assistant
"You are a helpful assistant.
Respond to messages professionally and friendly.
Keep responses concise (2-3 sentences max).
Stay focused on the user's question."
```

---

## Part 5: Advanced Features

### **1. Database History**

Add a PostgreSQL node to save all messages:

```
INSERT INTO messages 
(platform, from_id, message_text, reply_text, created_at)
VALUES 
({{$json.platform}}, 
 {{$json.from_id}}, 
 {{$json.message_text}}, 
 {{$node["Claude"].json.response}}, 
 NOW())
```

### **2. Smart Routing**

Add IF node to handle different message types:

```
IF message contains "order status"
  → Query database → Send order info

ELSE IF message contains "help"
  → Route to support team

ELSE
  → Generate AI reply
```

### **3. Sentiment Analysis**

Before AI reply, analyze sentiment:

```
Node: Code (Execute)

const sentiment = analyzeMessage(message)
if (sentiment.score < -0.5) {
  return "urgent_support_needed"
}
```

### **4. Rate Limiting**

Prevent spam:

```
Node: Set

Check: Last message time from this user
IF less than 5 seconds ago
  → Skip (rate limit)
ELSE
  → Process message
```

### **5. Human Handoff**

For complex queries:

```
IF Claude confidence < 0.6
  OR message mentions "human"
  → Send to support team (Slack/Email)
ELSE
  → Send AI reply
```

---

## Part 6: Testing

### **Test Instagram/Facebook**

1. Send DM to your Instagram/Facebook page
2. Check n8n execution logs
3. Verify bot reply appears

### **Test WhatsApp**

1. Send message to Twilio WhatsApp number
2. Check execution
3. Verify reply appears

### **Debug Checklist**

```
✓ Webhook URL in meta app matches n8n webhook path
✓ Verify token set in both places
✓ API credentials correct and saved
✓ Claude/OpenAI API key valid
✓ Message parsing correct (check JSON structure)
✓ Response generation working (test in Editor)
✓ Send node has correct recipient field
✓ Activation is ON in n8n
```

---

## Part 7: Deployment Checklist

- [ ] Test each platform separately
- [ ] Verify AI responses quality
- [ ] Set up database logging
- [ ] Configure rate limiting
- [ ] Add error handling (email on failure)
- [ ] Test with real messages
- [ ] Monitor first 24 hours
- [ ] Add sentiment analysis
- [ ] Set up analytics dashboard
- [ ] Document responses for compliance

---

## Part 8: Troubleshooting

| Issue | Solution |
|-------|----------|
| Messages not arriving | Check webhook URL, verify token, test with curl |
| No reply sent | Check AI credentials, verify message parsing |
| Wrong format | Check JSON structure of incoming message |
| Rate limit errors | Add delay node, implement queue |
| Timeouts | Increase max tokens, reduce response size |
| Cost concerns | Use GPT-4 mini, set max tokens to 100 |

---

## Part 9: Webhook URLs for Setup

### **In Meta App Settings**:
```
Instagram/Facebook Webhook URL:
http://YOUR_N8N_DOMAIN/webhook/instagram-facebook

Verify Token: n8n_meta_bot_2024

Subscribed Topics:
✓ messages
✓ messaging_postbacks
✓ message_template_status_update
```

### **In Twilio Settings** (for WhatsApp):
```
WhatsApp Webhook URL:
http://YOUR_N8N_DOMAIN/webhook/whatsapp

Method: POST

Status Callback URL:
http://YOUR_N8N_DOMAIN/webhook/whatsapp-status
```

---

## Next Steps

1. **Get all API credentials** (Meta, Twilio, Claude/OpenAI)
2. **Create first workflow** in n8n (Instagram + Facebook)
3. **Test with sample messages**
4. **Add WhatsApp** in second workflow
5. **Deploy and monitor**
6. **Add advanced features** (logging, routing, analytics)

---

## Security Best Practices

```
✓ Store API keys in n8n credentials (encrypted)
✓ Use webhook paths that are not predictable
✓ Implement rate limiting
✓ Log all messages (comply with regulations)
✓ Don't expose API keys in logs
✓ Use environment variables for sensitive data
✓ Monitor for abuse/spam
✓ Implement GDPR compliance (data retention)
✓ Use HTTPS/TLS for all connections
✓ Validate incoming webhook signatures
```

---

## Cost Estimates (Monthly)

| Service | Free Tier | Cost |
|---------|-----------|------|
| Meta (Instagram/Facebook) | Free | $0 (included) |
| Twilio WhatsApp | 100 messages | $0.0075/msg after |
| Claude API | - | $0.003 per 1K input tokens |
| n8n Docker | Unlimited | $0 (self-hosted) |
| **Total** | **100 msgs/mo** | **~$10-50/mo** |


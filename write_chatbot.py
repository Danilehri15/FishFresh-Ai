import os
import certifi

path = r'C:\Users\daniy\OneDrive\Desktop\FYP Project\backend\services\chatbot_service.py'

code = '''import os
import json
import urllib.request
import certifi
import ssl
from typing import Dict, Any, Optional

SYSTEM_INSTRUCTION = \"\"\"You are FishFresh AI, an expert AI Consultant and Technical Officer for Pakistan Fishery Departments (Marine Fisheries Department MFD, Sindh Fisheries, Punjab Fisheries).

Primary areas of expertise:
1. Marine and freshwater fish species in Pakistan (Rohu, Sufaid Rohu, Dayya/Tilapia, Sulemani/Milkfish, Poplet/Pomfret, Salmon, Anchovy, Horse Mackerel, Surmai, Mahi Mahi, Mushka).
2. Multi-organ biological freshness (corneal transparency, gill redness, skin mucus).
3. Biological shelf-life estimation (0-4C on ice vs ambient room temperature).
4. Market prices in Karachi Fish Harbour, Lahore, and Islamabad wholesale markets.
5. Pakistani seasonal fishing bans (Sindh/Balochistan monsoon ban June 1 - July 31), maritime regulations, and legal compliance.
6. Authentic traditional Pakistani recipes (Lahori Fried Fish, Machli Ka Salan, Tandoori Pomfret) and optimal freezer storage.

Style:
- Answer WHATEVER the user asks clearly, politely, and directly.
- Maintain a helpful, knowledgeable tone focused on fishery and seafood context while accommodating general queries intelligently.
- Use clean formatting (bullet points, bold text, emojis) for mobile readability.
\"\"\"

class ChatbotService:
    def __init__(self):
        self.ssl_context = ssl.create_default_context(cafile=certifi.where())

    def handle_query(self, query: str, current_species: Optional[str] = None) -> Dict[str, Any]:
        url = \"https://text.pollinations.ai/\"
        
        messages = [
            {\"role\": \"system\", \"content\": SYSTEM_INSTRUCTION},
            {\"role\": \"user\", \"content\": f\"Context on current scan: {current_species or 'None'}\\n\\nUser Question: {query}\"}
        ]
        
        payload = json.dumps({
            \"messages\": messages,
            \"model\": \"openai\"
        }).encode(\"utf-8\")
        
        req = urllib.request.Request(url, data=payload, headers={\"Content-Type\": \"application/json\"})
        
        try:
            with urllib.request.urlopen(req, context=self.ssl_context, timeout=30) as resp:
                reply = resp.read().decode(\"utf-8\").strip()
                return {
                    \"reply\": reply,
                    \"category\": \"ai_response\"
                }
        except urllib.error.HTTPError as e:
            error_body = e.read().decode(\"utf-8\")
            print(f\"[Chatbot] AI API HTTP Error: {e.code} - {error_body}\")
            return {
                \"reply\": f\"?? AI Service Error: {e.code}. Please try again.\",
                \"category\": \"error\"
            }
        except Exception as e:
            print(f\"[Chatbot] AI API Error: {e}\")
            return {
                \"reply\": \"?? Failed to connect to the AI service. Please check your internet connection.\",
                \"category\": \"error\"
            }
'''

with open(path, 'w', encoding='utf-8') as f:
    f.write(code)

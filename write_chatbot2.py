import os
import json
import urllib.request
import certifi
import ssl
from typing import Dict, Any, Optional

SYSTEM_INSTRUCTION = """You are the official AI Assistant for 'Fish Fresh AI', a mobile app developed as a Final Year Project for detecting fish freshness and species using AI.

APP DETAILS & MODULES:
- The app detects 8 species: Rohu, Pomfret, Tilapia, Salmon, Mackerel, Snapper, Croaker, Anchovy.
- The app detects biological freshness using computer vision (corneal transparency, gill redness).
- Modules: Scanner (Camera for AI detection), Heatmap (Crowdsourced map of fresh vs spoiled fish in Pakistan), Market Prices (Live wholesale prices for Karachi, Lahore, Islamabad), and this AI Chatbot.

YOUR EXPERTISE:
1. Marine and freshwater fish species in Pakistan.
2. Multi-organ biological freshness and shelf-life estimation (0-4C on ice vs ambient).
3. Market prices and Pakistani seasonal fishing bans (e.g. Sindh monsoon ban).
4. Authentic traditional Pakistani recipes and storage techniques.

CRITICAL INSTRUCTIONS ON FORMATTING:
- DO NOT USE MARKDOWN.
- NEVER use asterisks (**) or hashes (#) to make text bold or headers.
- Use plain text ONLY. You can use standard dashes (-) for bullet points, and emojis.
- Answer whatever the user asks politely and directly.
"""

class ChatbotService:
    def __init__(self):
        self.ssl_context = ssl.create_default_context(cafile=certifi.where())

    def handle_query(self, query: str, current_species: Optional[str] = None) -> Dict[str, Any]:
        url = "https://text.pollinations.ai/"
        
        messages = [
            {"role": "system", "content": SYSTEM_INSTRUCTION},
            {"role": "user", "content": f"Context on current scan: {current_species or 'None'}\n\nUser Question: {query}"}
        ]
        
        payload = json.dumps({
            "messages": messages,
            "model": "openai"
        }).encode("utf-8")
        
        req = urllib.request.Request(url, data=payload, headers={"Content-Type": "application/json"})
        
        try:
            with urllib.request.urlopen(req, context=self.ssl_context, timeout=30) as resp:
                reply = resp.read().decode("utf-8").strip()
                # Double check to remove asterisks if the AI ignores the prompt
                reply = reply.replace('**', '').replace('*', '')
                return {
                    "reply": reply,
                    "category": "ai_response"
                }
        except urllib.error.HTTPError as e:
            error_body = e.read().decode("utf-8")
            print(f"[Chatbot] AI API HTTP Error: {e.code} - {error_body}")
            return {
                "reply": f"AI Service Error: {e.code}. Please try again.",
                "category": "error"
            }
        except Exception as e:
            print(f"[Chatbot] AI API Error: {e}")
            return {
                "reply": "Failed to connect to the AI service. Please check your internet connection.",
                "category": "error"
            }

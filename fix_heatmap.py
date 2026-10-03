import os

with open('hf_deploy/backend/services/market_recommendation_service.py', 'r', encoding='utf-8') as f:
    text = f.read()

# ADD IMPORTS
if 'from pymongo import MongoClient' not in text:
    text = text.replace('import random', 'import random\nimport os\nfrom pymongo import MongoClient\nimport certifi')

# UPDATE __INIT__
init_old = '''        self.scans = []\n        self._seed_data()'''

init_new = '''        self.scans = []
        self.db = None
        mongo_uri = os.getenv(\"MONGODB_URI\")
        if mongo_uri:
            try:
                client = MongoClient(mongo_uri, tlsCAFile=certifi.where(), serverSelectionTimeoutMS=2000)
                self.db = client[\"fish_fresh_db\"]
                
                # Load existing scans from Mongo
                db_scans = list(self.db.heatmap_scans.find({}, {\"_id\": 0}))
                if len(db_scans) > 0:
                    self.scans = db_scans
                    print(f\"[Heatmap] Loaded {len(self.scans)} scans from MongoDB.\")
                else:
                    self._seed_data()
                    # save seed data to mongo
                    if len(self.scans) > 0:
                        self.db.heatmap_scans.insert_many(self.scans)
            except Exception as e:
                print(f\"[Heatmap] MongoDB error: {e}\")
                self._seed_data()
        else:
            self._seed_data()'''

text = text.replace(init_old, init_new)

# UPDATE RECORD_SCAN
rec_old = '''        self.scans.append(scan)\n        return scan'''

rec_new = '''        self.scans.append(scan)
        if hasattr(self, 'db') and self.db is not None:
            try:
                self.db.heatmap_scans.insert_one(scan.copy())
            except Exception as e:
                print(f\"[Heatmap] Error saving scan to DB: {e}\")
        return scan'''
text = text.replace(rec_old, rec_new)

with open('hf_deploy/backend/services/market_recommendation_service.py', 'w', encoding='utf-8') as f:
    f.write(text)

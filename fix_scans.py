import os
import certifi
from pymongo import MongoClient
from dotenv import load_dotenv

load_dotenv()
client = MongoClient(os.getenv('MONGODB_URI'), tlsCAFile=certifi.where())
db = client['fish_fresh_db']

target_user_id = '1b0f02ba-d912-49b2-9752-cad233dcb67e'
result = db.scans.update_many({'user_id': 'default_user'}, {'$set': {'user_id': target_user_id}})
print(f'Migrated {result.modified_count} scans to {target_user_id}!')

for scan in db.scans.find({'user_id': target_user_id}):
    scan['scan_data']['user_id'] = target_user_id
    db.scans.replace_one({'_id': scan['_id']}, scan)
print('Updated inner scan_data user_ids as well.')

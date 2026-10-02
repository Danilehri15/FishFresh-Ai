from huggingface_hub import HfApi
import os

token = "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"
repo_id = "Danilehri15/fish-fresh-api"

api = HfApi(token=token)

print("Starting upload to Hugging Face...")
api.upload_folder(
    folder_path="hf_deploy",
    repo_id=repo_id,
    repo_type="space"
)
print("Upload complete!")


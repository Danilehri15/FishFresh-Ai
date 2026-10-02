from huggingface_hub import HfApi

token = "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"
repo_id = "Danilehri15/fish-fresh-api"
api = HfApi(token=token)

readme = """---
title: Fish Fresh Api
emoji: 🐟
colorFrom: blue
colorTo: green
sdk: docker
pinned: false
---

Check out the configuration reference at https://huggingface.co/docs/hub/spaces-config-reference
"""

with open("README.md", "w", encoding="utf-8") as f:
    f.write(readme)

api.upload_file(
    path_or_fileobj="README.md",
    path_in_repo="README.md",
    repo_id=repo_id,
    repo_type="space"
)
print("Updated SDK to Docker!")

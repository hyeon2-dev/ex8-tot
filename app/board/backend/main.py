from fastapi import FastAPI
from pydantic import BaseModel, Field

app = FastAPI()

posts = []


class PostCreate(BaseModel):
    title: str = Field(min_length=1, max_length=100)
    content: str = Field(min_length=1, max_length=2000)


@app.get("/health")
def health():
    return {"status": "ok"}


@app.get("/posts")
def get_posts():
    return posts


@app.post("/posts", status_code=201)
def create_post(body: PostCreate):
    post = {
        "id": len(posts) + 1,
        "title": body.title,
        "content": body.content,
    }
    posts.insert(0, post)
    return post
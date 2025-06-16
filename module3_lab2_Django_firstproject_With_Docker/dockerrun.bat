docker build . -t my-django-app:latest
docker run -e PYTHONUNBUFFERED=1 -p 8000:8000 my-django-app

# Use official Python image
FROM python:3.11-slim

# Set work directory
WORKDIR /app

# Copy files
COPY requirements.txt .
COPY app.py .

# Install dependencies
RUN pip install --no-cache-dir -r requirements.txt

# Expose the port
EXPOSE 3000

# Run Gunicorn for production
CMD ["gunicorn", "--bind", "0.0.0.0:3000", "app:app"]

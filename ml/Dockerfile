FROM python:3.12-slim

# System deps: libgomp for XGBoost/LightGBM, build tools for prophet/pystan
RUN apt-get update && apt-get install -y --no-install-recommends \
    libgomp1 \
    build-essential \
    gcc \
    g++ \
    && rm -rf /var/lib/apt/lists/*

WORKDIR /app

COPY requirements.txt .
RUN pip install --no-cache-dir -r requirements.txt

COPY . .

EXPOSE 5000
CMD ["python", "api.py"]

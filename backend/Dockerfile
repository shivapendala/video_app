# Node.js Express Backend Dockerfile
FROM node:18-alpine

WORKDIR /app

# Copy package manifests first for caching layers
COPY package*.json ./

# Install dependencies
RUN npm install --only=production

# Copy application source code
COPY . .

# Expose Node.js server port
EXPOSE 5000

# Start server
CMD ["node", "src/server.js"]

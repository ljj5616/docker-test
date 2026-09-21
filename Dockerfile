# Node.js 실행 환경
FROM node:24-bookworm-slim

WORKDIR /app

# 의존성 파일을 먼저 복사해 빌드 캐시 사용
COPY package.json package-lock.json ./
RUN npm ci --omit=dev --no-audit --no-fund

COPY src ./src
COPY public ./public

# 메모 저장 폴더를 일반 사용자도 쓸 수 있게 준비
RUN mkdir -p /app/data && chown node:node /app/data

ENV NODE_ENV=production \
    HOST=0.0.0.0 \
    PORT=3000 \
    DATA_DIR=/app/data

USER node
EXPOSE 3000

# 컨테이너에서는 PM2 없이 Node.js를 직접 실행
CMD ["node", "src/server.js"]

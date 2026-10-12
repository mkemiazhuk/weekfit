FROM node:24-alpine
LABEL org.opencontainers.image.source="https://github.com/mkemiazhuk/weekfit"
WORKDIR /app
ENV NODE_ENV=production
COPY --chown=node:node package.json server.mjs recognition.mjs auth.mjs ./
USER node
EXPOSE 8080
HEALTHCHECK --interval=30s --timeout=5s CMD node -e "fetch('http://127.0.0.1:'+(process.env.PORT||8080)+'/readyz').then(r=>process.exit(r.ok?0:1)).catch(()=>process.exit(1))"
CMD ["node", "server.mjs"]

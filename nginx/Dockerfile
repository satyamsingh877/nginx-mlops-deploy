FROM nginx:alpine

# Labels for better management
LABEL maintainer="devops@example.com"
LABEL version="1.0"
LABEL description="Nginx MLOps deployment"

# Remove default nginx configuration
RUN rm /etc/nginx/conf.d/default.conf

# Copy custom configuration
COPY nginx.conf /etc/nginx/nginx.conf

# Copy static files
COPY index.html /usr/share/nginx/html/index.html

# Create necessary directories
RUN mkdir -p /var/log/nginx /var/cache/nginx && \
    chown -R nginx:nginx /var/log/nginx /var/cache/nginx

# Expose port
EXPOSE 80

# Health check
HEALTHCHECK --interval=30s --timeout=3s --start-period=5s --retries=3 \
  CMD wget -q --spider http://localhost/ || exit 1

# Run as non-root user
USER nginx

CMD ["nginx", "-g", "daemon off;"]

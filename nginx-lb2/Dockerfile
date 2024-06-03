FROM openresty/openresty:alpine

# Install MySQL client library for Lua
RUN apk --no-cache add mysql-client

# Create a directory to store Lua scripts
RUN mkdir -p /usr/local/openresty/nginx/lua_scripts

# Copy the Lua script to the container
COPY lua_scripts/sliding_window_counter.lua /usr/local/openresty/nginx/lua_scripts/sliding_window_counter.lua
# Copy the nginx configuration file
COPY nginx.conf /usr/local/openresty/nginx/conf/nginx.conf

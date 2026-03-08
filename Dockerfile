FROM ruby:3.2.2-alpine

# Install dependencies (cmake required for h3 gem native extension)
RUN apk add --no-cache \
    build-base \
    cmake \
    postgresql-dev \
    postgresql-client \
    tzdata \
    nodejs \
    npm \
    git \
    imagemagick \
    vips-dev

# Set working directory
WORKDIR /app

# Install bundler
RUN gem install bundler

# Copy Gemfile and Gemfile.lock for reproducible builds
COPY Gemfile Gemfile.lock ./

# Install gems
RUN bundle install --jobs 4 --retry 3

# Copy application code
COPY . .

# Create required directories
RUN mkdir -p tmp/pids tmp/sockets log storage

# Default port; Railway etc. set PORT at runtime (used in puma.rb)
EXPOSE 3000

# Start server — puma.rb reads ENV PORT and binds to 0.0.0.0
CMD ["bundle", "exec", "puma", "-C", "config/puma.rb"]

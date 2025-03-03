#!/bin/bash

# Function to prompt for credentials
get_credentials() {
    # Clear any existing values
    SUBDOMAIN=""
    EMAIL=""
    TOKEN=""
    
    # Get subdomain
    while [ -z "$SUBDOMAIN" ]; do
        echo -n "Enter your Zendesk subdomain (if your URL is company.zendesk.com, enter 'company'): "
        read SUBDOMAIN
        if [ -z "$SUBDOMAIN" ]; then
            echo "Subdomain cannot be empty. Please try again."
        fi
    done
    
    # Get email
    while [ -z "$EMAIL" ]; do
        echo -n "Enter your Zendesk email: "
        read EMAIL
        if [[ ! "$EMAIL" =~ ^[A-Za-z0-9._%+-]+@[A-Za-z0-9.-]+\.[A-Za-z]{2,}$ ]]; then
            echo "Invalid email format. Please try again."
            EMAIL=""
        fi
    done
    
    # Get API token (without showing input)
    while [ -z "$TOKEN" ]; do
        echo -n "Enter your Zendesk API token (input will be hidden): "
        read -s TOKEN
        echo    # Add newline after hidden input
        if [ -z "$TOKEN" ]; then
            echo "API token cannot be empty. Please try again."
        fi
    done
    
    # Test the credentials
    echo "Testing connection to Zendesk..."
    AUTH=$(echo -n "${EMAIL}/token:${TOKEN}" | base64)
    TEST_RESPONSE=$(curl -s -w "%{http_code}" -H "Authorization: Basic ${AUTH}" \
         "https://${SUBDOMAIN}.zendesk.com/api/v2/help_center/articles.json")
    
    HTTP_CODE=${TEST_RESPONSE: -3}
    if [ "$HTTP_CODE" != "200" ]; then
        echo "Error: Could not connect to Zendesk. Please check your credentials."
        return 1
    fi
    
    echo "Connection successful!"
    return 0
}

# Get credentials
get_credentials || exit 1

# Create base directory and images directory
mkdir -p zendesk_articles/images

# Create base64 auth string
AUTH=$(echo -n "${EMAIL}/token:${TOKEN}" | base64)

# Function to download images from article content
download_images() {
    local article_id=$1
    local content=$2
    local image_urls=$(echo "$content" | grep -o 'src="[^"]*"' | cut -d'"' -f2)
    
    local image_dir="zendesk_articles/images/article_${article_id}"
    mkdir -p "$image_dir"
    
    local modified_content="$content"
    local i=1
    echo "$image_urls" | while read -r url; do
        if [ ! -z "$url" ]; then
            local ext=$(echo "$url" | grep -o '\.[^.]*$' || echo ".jpg")
            local filename="image_${i}${ext}"
            echo "Downloading image: $url"
            
            curl -s -L "$url" -o "${image_dir}/${filename}"
            modified_content=$(echo "$modified_content" | sed "s|$url|../images/article_${article_id}/${filename}|g")
            i=$((i+1))
        fi
    done
    echo "$modified_content"
}

# Get total number of articles
TOTAL=$(curl -s -H "Authorization: Basic ${AUTH}" \
     "https://${SUBDOMAIN}.zendesk.com/api/v2/help_center/articles.json" | \
     jq -r '.count')

echo "Found ${TOTAL} articles to download..."

# Create index.html
cat > zendesk_articles/index.html << EOF
<!DOCTYPE html>
<html>
<head>
    <title>Zendesk Knowledge Base Articles</title>
    <style>
        body { font-family: Arial, sans-serif; margin: 40px; }
        .article-list { list-style: none; padding: 0; }
        .article-item { margin: 10px 0; padding: 10px; border: 1px solid #eee; }
        .article-link { color: #1a73e8; text-decoration: none; }
        .article-link:hover { text-decoration: underline; }
        .article-meta { color: #666; font-size: 0.9em; margin-top: 5px; }
    </style>
</head>
<body>
    <h1>Zendesk Knowledge Base Articles</h1>
    <ul class="article-list">
EOF

# Download articles
curl -s -H "Authorization: Basic ${AUTH}" \
     "https://${SUBDOMAIN}.zendesk.com/api/v2/help_center/articles.json?per_page=100" | \
     jq -r '.articles[] | .id' | while read -r id; do
    echo "Downloading article ${id}..."
    
    article_json=$(curl -s -H "Authorization: Basic ${AUTH}" \
         "https://${SUBDOMAIN}.zendesk.com/api/v2/help_center/articles/${id}.json")
    
    title=$(echo "$article_json" | jq -r '.article.title')
    body=$(echo "$article_json" | jq -r '.article.body')
    url=$(echo "$article_json" | jq -r '.article.html_url')
    created=$(echo "$article_json" | jq -r '.article.created_at')
    updated=$(echo "$article_json" | jq -r '.article.updated_at')
    
    processed_body=$(download_images "$id" "$body")
    
    # Create HTML file for the article
    cat > "zendesk_articles/article_${id}.html" << EOF
<!DOCTYPE html>
<html>
<head>
    <title>${title}</title>
    <style>
        body { font-family: Arial, sans-serif; margin: 40px; max-width: 800px; line-height: 1.6; }
        img { max-width: 100%; height: auto; }
        .article-meta { color: #666; font-size: 0.9em; margin: 20px 0; }
        .back-link { display: inline-block; margin-bottom: 20px; color: #1a73e8; text-decoration: none; }
        .back-link:hover { text-decoration: underline; }
    </style>
</head>
<body>
    <a href="index.html" class="back-link">← Back to Article List</a>
    <h1>${title}</h1>
    <div class="article-meta">
        <div>Original URL: <a href="${url}">${url}</a></div>
        <div>Created: ${created}</div>
        <div>Updated: ${updated}</div>
    </div>
    <div class="article-content">
        ${processed_body}
    </div>
</body>
</html>
EOF

    # Add entry to index.html
    cat >> zendesk_articles/index.html << EOF
        <li class="article-item">
            <a href="article_${id}.html" class="article-link">${title}</a>
            <div class="article-meta">Updated: ${updated}</div>
        </li>
EOF

    echo "Saved article ${id}"
    sleep 0.5
done

# Close index.html
cat >> zendesk_articles/index.html << EOF
    </ul>
</body>
</html>
EOF

echo "Download complete. Check the zendesk_articles directory."
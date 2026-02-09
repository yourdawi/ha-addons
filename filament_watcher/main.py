import json
import time
import requests
import re
import sys
import os
import paho.mqtt.client as mqtt
from bs4 import BeautifulSoup

# Configuration
CONFIG_FILE = "config.json"
MQTT_BROKER = os.environ.get("MQTT_BROKER", "homeassistant.local")
MQTT_PORT = int(os.environ.get("MQTT_PORT", 1883))
MQTT_USER = os.environ.get("MQTT_USER", "")
MQTT_PASSWORD = os.environ.get("MQTT_PASSWORD", "")
CHECK_INTERVAL = int(os.environ.get("CHECK_INTERVAL", 300)) # 5 minutes

def load_config():
    with open(CONFIG_FILE, "r", encoding="utf-8") as f:
        return json.load(f)

def get_product_data(url):
    """Fetches the product page and extracts variant data from Schema.org JSON-LD."""
    try:
        headers = {
            "User-Agent": "Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/91.0.4472.124 Safari/537.36",
            "Accept": "text/html,application/xhtml+xml,application/xml;q=0.9,image/webp,*/*;q=0.8"
        }
        response = requests.get(url, headers=headers, timeout=20)
        response.raise_for_status()
        
        html = response.text
        soup = BeautifulSoup(html, 'html.parser')
        
        # Find JSON-LD script tags (Schema.org structured data)
        for script in soup.find_all('script', type='application/ld+json'):
            try:
                data = json.loads(script.string)
                
                # Handle both single object and array of objects
                if isinstance(data, list):
                    for item in data:
                        if item.get('@type') == 'ProductGroup' and 'hasVariant' in item:
                            return parse_schema_variants(item['hasVariant'])
                elif isinstance(data, dict):
                    if data.get('@type') == 'ProductGroup' and 'hasVariant' in data:
                        return parse_schema_variants(data['hasVariant'])
            except json.JSONDecodeError:
                continue
        
        print(f"Could not find Schema.org ProductGroup in {url}")
        
    except Exception as e:
        print(f"Error fetching {url}: {e}")
    return None

def parse_schema_variants(variants_data):
    """Convert Schema.org hasVariant format to our internal format."""
    result = []
    for v in variants_data:
        sku = v.get('sku', '')
        offers = v.get('offers', {})
        availability = offers.get('availability', '')
        
        # Determine if in stock based on Schema.org availability
        in_stock = 'InStock' in availability
        
        result.append({
            'id': int(sku) if sku.isdigit() else sku,
            'sku': sku,
            'name': v.get('name', ''),
            'available': in_stock,
            'availability_raw': availability,
            'price': offers.get('price'),
            'currency': offers.get('priceCurrency')
        })
    return result


def publish_mqtt(client, topic, payload):
    try:
        client.publish(topic, json.dumps(payload), retain=True)
        print(f"Published to {topic}: {payload['formatted_status']}")
    except Exception as e:
        print(f"MQTT Publish Error: {e}")

def main():
    print("Starting Filament Watcher...")
    
    # Setup MQTT
    client = mqtt.Client()
    if MQTT_USER and MQTT_PASSWORD:
        client.username_pw_set(MQTT_USER, MQTT_PASSWORD)
    
    try:
        client.connect(MQTT_BROKER, MQTT_PORT, 60)
        client.loop_start()
    except Exception as e:
        print(f"Could not connect to MQTT Broker: {e}")
        # Continue anyway to test scraping? No, loop might fail.
        # But maybe we just want to print status if MQTT fails.
    
    config = load_config()
    
    # Group items by URL to avoid spamming requests
    urls = {}
    for item in config:
        if item["url"] not in urls:
            urls[item["url"]] = []
        urls[item["url"]].append(item)
        
    while True:
        print(f"Checking stock... ({time.ctime()})")
        
        for url, items in urls.items():
            print(f"Fetching {url}...")
            variants = get_product_data(url)
            
            if variants:
                # Create a map of ID -> Variant Data
                variant_map = {v['id']: v for v in variants}
                
                for item in items:
                    vid = item["variant_id"]
                    name = item["name"]
                    
                    if vid in variant_map:
                        data = variant_map[vid]
                        available = data.get("available", False)
                        qty = data.get("inventory_quantity", 0)
                        
                        # Prepare payload
                        status = "in_stock" if available else "out_of_stock"
                        formatted = "Available" if available else "Sold Out"
                        
                        payload = {
                            "name": name,
                            "status": status,
                            "available": available,
                            "formatted_status": formatted,
                            "last_updated": time.strftime("%Y-%m-%dT%H:%M:%SZ", time.gmtime())
                        }
                        
                        # Add extra details if available
                        if "incoming" in data: # Hypothetical
                            payload["incoming"] = data["incoming"]
                        
                        # Topic: bambulab/filament/pla_matte_elfenbeinweiss
                        # Normalize name
                        safe_name = name.lower().replace(" ", "_").replace("-", "_").replace("ä", "ae").replace("ö", "oe").replace("ü", "ue").replace("ß", "ss")
                        topic = f"bambulab/filament/{safe_name}"
                        
                        publish_mqtt(client, topic, payload)
                    else:
                        print(f"Variant ID {vid} ({name}) not found in page data.")
            else:
                print(f"Could not get data for {url}")
                
            time.sleep(2) # Polite delay between different URLs
            
        print(f"Sleeping for {CHECK_INTERVAL} seconds...")
        time.sleep(CHECK_INTERVAL)

if __name__ == "__main__":
    main()

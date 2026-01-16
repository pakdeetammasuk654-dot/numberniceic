#!/usr/bin/env python3
"""
Generate telephone_type.json from numbers.json
This script analyzes number pairs and categorizes them by dominant aspect.
Output: telephone_type.json with pairs categorized by best enhancement effect.
"""

import json
import os

def load_numbers_json(filepath):
    """Load numbers.json file."""
    with open(filepath, 'r', encoding='utf-8') as f:
        return json.load(f)

def categorize_pairs(numbers_data):
    """
    Categorize pairs by their dominant aspect.
    A pair is dominant for an aspect if that aspect has the highest percentage.
    """
    categories = {
        'health': {
            'th': 'สุขภาพ',
            'description': 'เลขที่เสริมด้านสุขภาพ',
            'strong_pairs': [],  # >= 40%
            'moderate_pairs': [],  # >= 30%
        },
        'career': {
            'th': 'การงาน',
            'description': 'เลขที่เสริมด้านการงาน',
            'strong_pairs': [],
            'moderate_pairs': [],
        },
        'finance': {
            'th': 'การเงิน',
            'description': 'เลขที่เสริมด้านการเงิน',
            'strong_pairs': [],
            'moderate_pairs': [],
        },
        'love': {
            'th': 'ความรัก',
            'description': 'เลขที่เสริมด้านความรัก',
            'strong_pairs': [],
            'moderate_pairs': [],
        },
    }
    
    numbers = numbers_data.get('numbers', {})
    
    for pair_num, pair_data in numbers.items():
        aspects = pair_data.get('aspects', {})
        if not aspects:
            continue
        
        # Get percentages
        health_pct = aspects.get('health', {}).get('percentage', 0)
        career_pct = aspects.get('career', {}).get('percentage', 0)
        finance_pct = aspects.get('finance', {}).get('percentage', 0)
        love_pct = aspects.get('love', {}).get('percentage', 0)
        
        nature = pair_data.get('nature', 'neutral')
        pairpoint = pair_data.get('pairpoint', 0)
        summary = pair_data.get('summary', '')
        
        # Find dominant aspect(s)
        all_pcts = {
            'health': health_pct,
            'career': career_pct,
            'finance': finance_pct,
            'love': love_pct,
        }
        
        max_pct = max(all_pcts.values())
        
        # Create pair info
        pair_info = {
            'pair': pair_num,
            'percentage': max_pct,
            'nature': nature,
            'pairpoint': pairpoint,
            'summary': summary,
        }
        
        # Categorize by dominant aspect
        for aspect, pct in all_pcts.items():
            if pct == max_pct:  # This is the dominant aspect
                if pct >= 40:
                    categories[aspect]['strong_pairs'].append(pair_info.copy())
                elif pct >= 30:
                    categories[aspect]['moderate_pairs'].append(pair_info.copy())
    
    # Sort pairs by percentage (descending) and pairpoint (descending for positive)
    for cat in categories.values():
        cat['strong_pairs'].sort(key=lambda x: (-x['percentage'], -x['pairpoint']))
        cat['moderate_pairs'].sort(key=lambda x: (-x['percentage'], -x['pairpoint']))
    
    return categories

def generate_telephone_recommendations(categories):
    """
    Generate telephone number recommendations based on categorized pairs.
    """
    recommendations = {}
    
    for aspect, data in categories.items():
        # Collect best positive pairs (nature = positive or neutral with high pairpoint)
        best_pairs = []
        
        for pair in data['strong_pairs'] + data['moderate_pairs']:
            if pair['nature'] == 'positive' or (pair['nature'] == 'neutral' and pair['pairpoint'] >= 0):
                best_pairs.append(pair)
        
        # Sort by pairpoint then percentage
        best_pairs.sort(key=lambda x: (-x['pairpoint'], -x['percentage']))
        
        recommendations[aspect] = {
            'th': data['th'],
            'description': data['description'],
            'best_pairs': [p['pair'] for p in best_pairs[:10]],  # Top 10 pairs
            'details': best_pairs[:10],
            'total_strong': len(data['strong_pairs']),
            'total_moderate': len(data['moderate_pairs']),
        }
    
    return recommendations

def main():
    # Get script directory
    script_dir = os.path.dirname(os.path.abspath(__file__))
    numbers_json_path = os.path.join(script_dir, '../mobile_app/assets/numbers.json')
    output_path = os.path.join(script_dir, '../mobile_app/assets/telephone_type.json')
    
    print(f"📖 Loading numbers.json from: {numbers_json_path}")
    numbers_data = load_numbers_json(numbers_json_path)
    
    print("📊 Analyzing pairs by dominant aspect...")
    categories = categorize_pairs(numbers_data)
    
    print("📱 Generating telephone recommendations...")
    recommendations = generate_telephone_recommendations(categories)
    
    # Create output structure
    output = {
        'version': '1.0',
        'description': 'ประเภทเบอร์โทรศัพท์ที่เสริมแต่ละด้าน',
        'categories': recommendations,
        'usage': {
            'th': 'เลือกเบอร์โทรที่มีคู่เลขในหมวดที่ต้องการเสริม จะช่วยเพิ่ม % ในด้านนั้นอย่างมีนัยสำคัญ',
            'example': 'ถ้าต้องการเสริมด้านการเงิน ควรเลือกเบอร์ที่มีคู่เลข 24, 42, 19, 91 เป็นต้น',
        },
    }
    
    # Save output
    with open(output_path, 'w', encoding='utf-8') as f:
        json.dump(output, f, ensure_ascii=False, indent=2)
    
    print(f"✅ Generated telephone_type.json at: {output_path}")
    
    # Print summary
    print("\n📊 Summary:")
    for aspect, data in recommendations.items():
        print(f"  {data['th']}: {len(data['best_pairs'])} best pairs")
        if data['best_pairs']:
            print(f"    Top 5: {', '.join(data['best_pairs'][:5])}")

if __name__ == '__main__':
    main()

#!/usr/bin/env python3
"""
Parse numbers.sql and extract pairnumber data with categorized aspects.
Analyzes detail_vip and miracledetail fields to determine percentages for:
1. ด้านสุขภาพ (Health)
2. ด้านการงาน (Work/Career)
3. ด้านการเงิน (Finance)
4. ด้านความรัก (Love)
"""

import re
import json
from pathlib import Path

# Keywords for each category
HEALTH_KEYWORDS = [
    'สุขภาพ', 'โรค', 'เจ็บ', 'ป่วย', 'ผ่าตัด', 'อุบัติเหตุ', 'ร่างกาย', 'เรื้อรัง',
    'มะเร็ง', 'กระดูก', 'ประสาท', 'สมอง', 'ตา', 'หัวใจ', 'ความดัน', 'ไมเกรน',
    'ภูมิแพ้', 'กระเพาะ', 'ลำไส้', 'ไต', 'ตับ', 'ระบบประสาท', 'อ่อนแอ', 'แข็งแรง',
    'อายุยืน', 'ชีวิต', 'ตาย', 'สิ้น', 'แข็งแกร่ง', 'ทนทาน', 'ผิวหนัง', 'เลือด',
    'ซีสต์', 'เนื้องอก', 'ปวด', 'บาดเจ็บ', 'เอ็น', 'ข้อ', 'หลัง', 'คอ', 'หัว',
    'ฟัน', 'ติดเชื้อ', 'อัมพาต', 'นิ่ว', 'ถุงน้ำดี', 'มดลูก', 'รังไข่', 'ต่อมลูกหมาก'
]

CAREER_KEYWORDS = [
    'การงาน', 'หน้าที่', 'ตำแหน่ง', 'ทำงาน', 'อาชีพ', 'ธุรกิจ', 'กิจการ', 
    'ก้าวหน้า', 'เลื่อนขั้น', 'ผู้บริหาร', 'เจ้าของ', 'ข้าราชการ', 'ทหาร', 'ตำรวจ',
    'นักการเมือง', 'ผู้จัดการ', 'ผู้นำ', 'ลูกน้อง', 'บริวาร', 'สำเร็จ', 'ล้มเหลว',
    'สายงาน', 'เจ้านาย', 'หัวหน้า', 'พนักงาน', 'ค้าขาย', 'พ่อค้า', 'แม่ค้า',
    'นักธุรกิจ', 'ประสบความสำเร็จ', 'รุ่งเรือง', 'ก้าวกระโดด', 'รุ่งโรจน์',
    'การศึกษา', 'เรียน', 'สอบ', 'แข่งขัน', 'ชนะ', 'แพ้', 'ทนายความ', 'ผู้พิพากษา',
    'ศิลปิน', 'ดารา', 'นักแสดง', 'นักเขียน', 'นักออกแบบ', 'ครู', 'อาจารย์'
]

FINANCE_KEYWORDS = [
    'การเงิน', 'เงิน', 'ทอง', 'ทรัพย์', 'สมบัติ', 'ร่ำรวย', 'รวย', 'ยากจน', 'จน',
    'หนี้', 'ล้มละลาย', 'หมดตัว', 'ขาดทุน', 'กำไร', 'โชคลาภ', 'ลาภ', 'โชค',
    'เศรษฐี', 'มั่งคั่ง', 'อุดมสมบูรณ์', 'ไม่ขาดมือ', 'ได้เงิน', 'เสียเงิน',
    'ลงทุน', 'ทุน', 'ขาดแคลน', 'ฐานะ', 'มีอันจะกิน', 'ไหลมา', 'ไหลเข้า',
    'หาเงิน', 'ใช้เงิน', 'สินทรัพย์', 'มรดก', 'พึ่งพา', 'อุปถัมภ์', 'ค้าขาย',
    'รายได้', 'เงินทอง', 'ทรัพย์สิน', 'เงินๆทองๆ', 'คู่ทรัพย์', 'คู่โชค'
]

LOVE_KEYWORDS = [
    'ความรัก', 'รัก', 'แฟน', 'คู่', 'ครอบครัว', 'สมรส', 'แต่งงาน', 'หย่า', 'เลิก',
    'คู่ครอง', 'ครองคู่', 'สามี', 'ภรรยา', 'เมีย', 'ผัว', 'พลัดพราก', 'อาภัพรัก',
    'เจ้าชู้', 'ชู้', 'กิ๊ก', 'มือที่สาม', 'รักสามเศร้า', 'นอกใจ', 'หลอกลวง',
    'เมียน้อย', 'หม้าย', 'ขึ้นคาน', 'อบอุ่น', 'เย็นชา', 'ใกล้ชิด', 'ห่างเหิน',
    'สวาท', 'หลงรัก', 'ตกหลุมรัก', 'อกหัก', 'ผิดหวัง', 'เสน่ห์', 'ดึงดูด',
    'เพศตรงข้าม', 'มีคู่', 'ไร้คู่', 'โสด', 'ลูก', 'หลาน', 'บ้านแตก', 'สาแหรกขาด',
    'ครอบครัวแตกแยก', 'ทะเลาะ', 'ปากเสียง', 'เข้าใจกัน', 'มีรัก', 'สมหวัง'
]

def count_keywords(text, keywords):
    """Count keyword occurrences in text."""
    if not text:
        return 0
    text_lower = text.lower()
    count = 0
    for keyword in keywords:
        count += len(re.findall(re.escape(keyword.lower()), text_lower))
    return count

def analyze_text(detail_vip, miracledetail):
    """Analyze text and return percentage distribution for 4 aspects."""
    combined_text = f"{detail_vip or ''} {miracledetail or ''}"
    
    health_count = count_keywords(combined_text, HEALTH_KEYWORDS)
    career_count = count_keywords(combined_text, CAREER_KEYWORDS)
    finance_count = count_keywords(combined_text, FINANCE_KEYWORDS)
    love_count = count_keywords(combined_text, LOVE_KEYWORDS)
    
    total = health_count + career_count + finance_count + love_count
    
    if total == 0:
        # Default distribution if no keywords found
        return {
            "health": 25,
            "career": 25,
            "finance": 25,
            "love": 25
        }
    
    # Calculate percentages
    health_pct = round((health_count / total) * 100)
    career_pct = round((career_count / total) * 100)
    finance_pct = round((finance_count / total) * 100)
    love_pct = round((love_count / total) * 100)
    
    # Ensure they sum to 100
    diff = 100 - (health_pct + career_pct + finance_pct + love_pct)
    if diff != 0:
        # Add difference to the largest category
        max_cat = max([(health_pct, 'health'), (career_pct, 'career'), 
                       (finance_pct, 'finance'), (love_pct, 'love')])
        if max_cat[1] == 'health':
            health_pct += diff
        elif max_cat[1] == 'career':
            career_pct += diff
        elif max_cat[1] == 'finance':
            finance_pct += diff
        else:
            love_pct += diff
    
    return {
        "health": health_pct,
        "career": career_pct,
        "finance": finance_pct,
        "love": love_pct
    }

def determine_overall_nature(pairpoint, detail_vip):
    """Determine if the number pair is positive, negative, or neutral."""
    if pairpoint is None:
        return "neutral"
    if pairpoint >= 50:
        return "positive"
    elif pairpoint <= -50:
        return "negative"
    else:
        return "neutral"

def generate_summary(pairnumber, nature, aspects, pairpoint, miracledesc):
    """Generate a short Thai summary description for the number pair."""
    
    # Find dominant aspect
    aspect_scores = [
        (aspects["health"], "health", "สุขภาพ"),
        (aspects["career"], "career", "การงาน"),
        (aspects["finance"], "finance", "การเงิน"),
        (aspects["love"], "love", "ความรัก")
    ]
    aspect_scores.sort(key=lambda x: x[0], reverse=True)
    dominant = aspect_scores[0]
    second = aspect_scores[1]
    
    # Nature descriptions
    if nature == "positive":
        nature_prefix = "เลขมงคล"
        nature_desc = "ส่งเสริม"
    elif nature == "negative":
        nature_prefix = "เลขควรระวัง"
        nature_desc = "ต้องระวัง"
    else:
        nature_prefix = "เลขกลาง"
        nature_desc = "มีทั้งดีและควรระวัง"
    
    # Aspect descriptions
    aspect_details = {
        "health": {
            "positive": "สุขภาพแข็งแรง มีพลังชีวิต",
            "negative": "ต้องระวังสุขภาพและอุบัติเหตุ",
            "neutral": "ควรดูแลสุขภาพให้ดี"
        },
        "career": {
            "positive": "หน้าที่การงานรุ่งเรือง ประสบความสำเร็จ",
            "negative": "การงานมีอุปสรรค ต้องฝ่าฟัน",
            "neutral": "การงานมีขึ้นมีลง"
        },
        "finance": {
            "positive": "เงินทองไหลมาเทมา โชคลาภดี",
            "negative": "ต้องระวังเรื่องการเงิน หนี้สิน",
            "neutral": "การเงินไม่แน่นอน"
        },
        "love": {
            "positive": "ความรักราบรื่น มีคู่ครองที่ดี",
            "negative": "ความรักไม่ราบรื่น อาจพลัดพราก",
            "neutral": "ความรักมีทั้งสุขและทุกข์"
        }
    }
    
    # Generate summary based on dominant aspect and nature
    dominant_key = dominant[1]
    dominant_detail = aspect_details[dominant_key][nature]
    
    # Create summary
    if dominant[0] >= 40:
        # Very dominant aspect
        summary = f"{nature_prefix} เด่นด้าน{dominant[2]} ({dominant[0]}%) - {dominant_detail}"
    elif dominant[0] >= 30:
        # Moderately dominant
        second_key = second[1]
        summary = f"{nature_prefix} เด่นด้าน{dominant[2]}และ{second[2]} - {dominant_detail}"
    else:
        # Balanced
        summary = f"{nature_prefix} มีความสมดุลทุกด้าน - {nature_desc}ในทุกเรื่อง"
    
    return summary

def generate_aspect_insights(nature, aspects):
    """Generate detailed insights for each aspect."""
    insights = {}
    
    aspect_insights = {
        "health": {
            "high_positive": "พลังชีวิตสูง ร่างกายแข็งแรง อายุยืน",
            "high_negative": "ต้องระวังสุขภาพ อุบัติเหตุ โรคเรื้อรัง",
            "medium_positive": "สุขภาพดี แต่ควรดูแลตัวเอง",
            "medium_negative": "มีโอกาสเจ็บป่วยบ้าง",
            "low": "ไม่มีผลกระทบด้านสุขภาพมาก"
        },
        "career": {
            "high_positive": "การงานรุ่งเรือง มีตำแหน่งสูง ประสบความสำเร็จ",
            "high_negative": "การงานมีอุปสรรค ถูกกลั่นแกล้ง ต้องระวัง",
            "medium_positive": "การงานดี มีความก้าวหน้า",
            "medium_negative": "การงานมีปัญหาบ้าง",
            "low": "ไม่มีผลกระทบด้านการงานมาก"
        },
        "finance": {
            "high_positive": "เงินทองไหลมาเทมา ร่ำรวย มีโชคลาภ",
            "high_negative": "ต้องระวังเรื่องเงิน หนี้สิน ล้มละลาย",
            "medium_positive": "การเงินดี มีเงินใช้ไม่ขาดมือ",
            "medium_negative": "การเงินมีปัญหาบ้าง ต้องรอบคอบ",
            "low": "ไม่มีผลกระทบด้านการเงินมาก"
        },
        "love": {
            "high_positive": "ความรักราบรื่น มีเสน่ห์ มีคู่ครองที่ดี",
            "high_negative": "ความรักไม่สมหวัง อาภัพรัก พลัดพราก",
            "medium_positive": "ความรักดี มีคนรักใคร่",
            "medium_negative": "ความรักมีปัญหา ต้องระวัง",
            "low": "ไม่มีผลกระทบด้านความรักมาก"
        }
    }
    
    for aspect_key, percentage in aspects.items():
        if percentage >= 35:
            level = "high_positive" if nature == "positive" else "high_negative"
        elif percentage >= 20:
            level = "medium_positive" if nature == "positive" else "medium_negative"
        else:
            level = "low"
        
        insights[aspect_key] = aspect_insights[aspect_key][level]
    
    return insights

def parse_sql_file(sql_path):
    """Parse the SQL file and extract number data."""
    with open(sql_path, 'r', encoding='utf-8') as f:
        content = f.read()
    
    # Pattern to match INSERT statements
    pattern = r"INSERT INTO public\.numbers.*?VALUES\s*\('(.*?)',\s*'(.*?)',\s*'(.*?)',\s*'(.*?)',\s*'(.*?)',\s*(\d+),\s*(-?\d+)\);"
    
    # For multi-line entries, we need a different approach
    # Split by INSERT INTO
    entries = content.split("INSERT INTO public.numbers")
    
    numbers_data = {}
    
    for entry in entries[1:]:  # Skip first empty split
        try:
            # Find VALUES clause
            values_match = re.search(r"VALUES\s*\('", entry)
            if not values_match:
                continue
            
            values_start = values_match.end() - 1  # Include opening quote
            values_section = entry[values_start:]
            
            # Parse the values more carefully
            # Format: ('detail_vip', 'pairtype', 'pairnumber', 'miracledetail', 'miracledesc', pairnumberid, pairpoint);
            
            parts = []
            current_part = ""
            in_string = False
            escape_next = False
            
            i = 0
            while i < len(values_section):
                char = values_section[i]
                
                if escape_next:
                    current_part += char
                    escape_next = False
                elif char == '\\':
                    escape_next = True
                    current_part += char
                elif char == "'" and not in_string:
                    in_string = True
                elif char == "'" and in_string:
                    # Check if it's escaped quote
                    if i + 1 < len(values_section) and values_section[i + 1] == "'":
                        current_part += "'"
                        i += 1
                    else:
                        in_string = False
                        parts.append(current_part)
                        current_part = ""
                elif in_string:
                    current_part += char
                elif char == ')' and not in_string:
                    # End of values, get the numeric parts
                    remaining = current_part.strip().strip(',').split(',')
                    for r in remaining:
                        r = r.strip()
                        if r:
                            parts.append(r)
                    break
                elif char == ',' and not in_string:
                    if current_part.strip():
                        parts.append(current_part.strip())
                    current_part = ""
                else:
                    current_part += char
                
                i += 1
            
            if len(parts) >= 7:
                detail_vip = parts[0]
                pairtype = parts[1].strip()
                pairnumber = parts[2].strip()
                miracledetail = parts[3]
                miracledesc = parts[4].strip() if len(parts) > 4 else ""
                pairnumberid = int(parts[5]) if len(parts) > 5 and parts[5].isdigit() else 0
                pairpoint = int(parts[6]) if len(parts) > 6 else 0
                
                # Analyze the text for aspect distribution
                aspects = analyze_text(detail_vip, miracledetail)
                nature = determine_overall_nature(pairpoint, detail_vip)
                
                # Generate summary and insights
                summary = generate_summary(pairnumber, nature, aspects, pairpoint, miracledesc)
                aspect_insights = generate_aspect_insights(nature, aspects)
                
                numbers_data[pairnumber] = {
                    "pairnumber": pairnumber,
                    "pairtype": pairtype,
                    "pairpoint": pairpoint,
                    "nature": nature,
                    "summary": summary,
                    "miracledesc": miracledesc,
                    "detail_vip": detail_vip,
                    "miracledetail": miracledetail,
                    "aspects": {
                        "health": {
                            "th": "ด้านสุขภาพ",
                            "percentage": aspects["health"],
                            "insight": aspect_insights["health"]
                        },
                        "career": {
                            "th": "ด้านการงาน", 
                            "percentage": aspects["career"],
                            "insight": aspect_insights["career"]
                        },
                        "finance": {
                            "th": "ด้านการเงิน",
                            "percentage": aspects["finance"],
                            "insight": aspect_insights["finance"]
                        },
                        "love": {
                            "th": "ด้านความรัก",
                            "percentage": aspects["love"],
                            "insight": aspect_insights["love"]
                        }
                    }
                }
        except Exception as e:
            print(f"Error parsing entry: {e}")
            continue
    
    return numbers_data

def main():
    script_dir = Path(__file__).parent
    sql_path = script_dir.parent / "numbers.sql"
    output_path = script_dir.parent / "mobile_app" / "assets" / "numbers.json"
    
    # Ensure output directory exists
    output_path.parent.mkdir(parents=True, exist_ok=True)
    
    print(f"Parsing SQL file: {sql_path}")
    numbers_data = parse_sql_file(sql_path)
    
    # Create output structure
    output = {
        "version": "1.0",
        "description": "Number pair meanings with aspect percentages for ช้อยนิยม พยากรณ์",
        "aspectLabels": {
            "health": {"th": "ด้านสุขภาพ", "en": "Health"},
            "career": {"th": "ด้านการงาน", "en": "Career"},
            "finance": {"th": "ด้านการเงิน", "en": "Finance"},
            "love": {"th": "ด้านความรัก", "en": "Love"}
        },
        "numbers": numbers_data
    }
    
    # Write to JSON file
    with open(output_path, 'w', encoding='utf-8') as f:
        json.dump(output, f, ensure_ascii=False, indent=2)
    
    print(f"Successfully exported {len(numbers_data)} number pairs to: {output_path}")
    print(f"\nSample entry:")
    if numbers_data:
        sample_key = list(numbers_data.keys())[0]
        sample = numbers_data[sample_key]
        print(f"  Pair: {sample['pairnumber']}")
        print(f"  Point: {sample['pairpoint']}")
        print(f"  Nature: {sample['nature']}")
        print(f"  Summary: {sample['summary']}")
        print(f"  Aspects:")
        for aspect, data in sample['aspects'].items():
            print(f"    {data['th']}: {data['percentage']}% - {data['insight']}")

if __name__ == "__main__":
    main()

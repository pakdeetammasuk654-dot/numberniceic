#!/bin/bash
NAMES=("กาญจนาภรณ์" "สุวรรณภูมิ" "รัตนโกสินทร์" "พระนครศรีอยุธยา" "บุญญาฤทธิ์" "อัครพล")

for NAME in "${NAMES[@]}"; do
    echo "Testing: $NAME"
    COUNT=$(curl -s "http://localhost:3000/analyzer?name=$(echo $NAME | xxd -plain | tr -d '\n' | sed 's/\(..\)/%\1/g')" | grep -o "meaning-item" | wc -l)
    OVERLAY=$(curl -s "http://localhost:3000/analyzer?name=$(echo $NAME | xxd -plain | tr -d '\n' | sed 's/\(..\)/%\1/g')" | grep -c "vip-upgrade-overlay")
    
    echo "  Items: $COUNT"
    echo "  Overlay: $OVERLAY"
    echo "---"
done


class PctItem {
  String cat;
  bool isGood;
  double original;
  double remainder;
  int floorVal;
  PctItem(this.cat, this.isGood, this.original) 
      : floorVal = original.floor(), remainder = original - original.floor();
}

/// Thin sort helpers that operate on generic comparable lists in-place.
class ListUtil {
  static List sortDesc(List list) {
    return list..sort((e1, e2) => e2.compareTo(e1));
  }
}

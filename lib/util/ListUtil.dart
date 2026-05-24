class ListUtil {
  static List sortAsc(List list) {
    return list..sort((e1, e2) => e2.compareTo(e1));
  }

  static List sortDesc(List list) {
    return list..sort((e1, e2) => e1.compareTo(e2));
  }
}

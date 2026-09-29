// Adapted from Microsoft STL vs-2019-16.6, stl/inc/algorithm.
// Copyright (c) Microsoft Corporation.
// SPDX-License-Identifier: Apache-2.0 WITH LLVM-exception
// Modifications: names/iterator plumbing simplified; heap operations specialize
// the same ordering recovered at Blink RVAs 131af60/131ae50. This preserves
// equal-score ordering, which libc++ std::sort does not promise to reproduce.
#pragma once
#include <algorithm>
#include <iterator>
#include <utility>

namespace odyssey_detection_order {
template <class It, class Compare> void median3(It first, It middle, It last, Compare before) {
  if (before(*middle, *first))
    std::iter_swap(middle, first);
  if (before(*last, *middle)) {
    std::iter_swap(last, middle);
    if (before(*middle, *first))
      std::iter_swap(middle, first);
  }
}
template <class It, class Compare> std::pair<It, It> partition(It first, It last, Compare before) {
  It middle = first + ((last - first) >> 1);
  const auto count = last - first - 1;
  if (count > 40) {
    const auto step = (count + 1) >> 3;
    median3(first, first + step, first + 2 * step, before);
    median3(middle - step, middle, middle + step, before);
    median3(last - 1 - 2 * step, last - 1 - step, last - 1, before);
    median3(first + step, middle, last - 1 - step, before);
  } else
    median3(first, middle, last - 1, before);
  It pivotFirst = middle, pivotLast = middle + 1;
  while (first < pivotFirst && !before(*(pivotFirst - 1), *pivotFirst) &&
         !before(*pivotFirst, *(pivotFirst - 1)))
    --pivotFirst;
  while (pivotLast < last && !before(*pivotLast, *pivotFirst) && !before(*pivotFirst, *pivotLast))
    ++pivotLast;
  It scanFirst = pivotLast, scanLast = pivotFirst;
  for (;;) {
    for (; scanFirst < last; ++scanFirst) {
      if (before(*pivotFirst, *scanFirst))
        continue;
      if (before(*scanFirst, *pivotFirst))
        break;
      if (pivotLast != scanFirst)
        std::iter_swap(pivotLast, scanFirst);
      ++pivotLast;
    }
    for (; first < scanLast; --scanLast) {
      if (before(*(scanLast - 1), *pivotFirst))
        continue;
      if (before(*pivotFirst, *(scanLast - 1)))
        break;
      if (--pivotFirst != scanLast - 1)
        std::iter_swap(pivotFirst, scanLast - 1);
    }
    if (scanLast == first && scanFirst == last)
      return {pivotFirst, pivotLast};
    if (scanLast == first) {
      if (pivotLast != scanFirst)
        std::iter_swap(pivotFirst, pivotLast);
      ++pivotLast;
      std::iter_swap(pivotFirst, scanFirst);
      ++pivotFirst;
      ++scanFirst;
    } else if (scanFirst == last) {
      if (--scanLast != --pivotFirst)
        std::iter_swap(scanLast, pivotFirst);
      std::iter_swap(pivotFirst, --pivotLast);
    } else {
      std::iter_swap(scanFirst, --scanLast);
      ++scanFirst;
    }
  }
}
template <class It, class Compare>
void heapPlace(It first, std::ptrdiff_t hole, std::ptrdiff_t count,
               typename std::iterator_traits<It>::value_type value, Compare before) {
  const auto top = hole, lastParent = (count - 1) >> 1;
  while (hole < lastParent) {
    auto child = hole * 2 + 2;
    if (before(first[child], first[child - 1]))
      --child;
    first[hole] = first[child];
    hole = child;
  }
  if (hole == lastParent && !(count & 1)) {
    first[hole] = first[count - 1];
    hole = count - 1;
  }
  while (top < hole) {
    const auto parent = (hole - 1) >> 1;
    if (!before(first[parent], value))
      break;
    first[hole] = first[parent];
    hole = parent;
  }
  first[hole] = value;
}
template <class It, class Compare>
void sort(It first, It last, std::ptrdiff_t ideal, Compare before) {
  for (;;) {
    if (last - first <= 32) {
      if (first != last)
        for (It next = first + 1; next != last; ++next) {
          const auto value = *next;
          It hole = next;
          while (hole != first && before(value, *(hole - 1))) {
            *hole = *(hole - 1);
            --hole;
          }
          *hole = value;
        }
      return;
    }
    if (ideal <= 0) {
      const auto count = last - first;
      for (auto index = count >> 1; index > 0;) {
        --index;
        heapPlace(first, index, count, first[index], before);
      }
      for (auto length = count; length > 1;) {
        --length;
        const auto value = first[length];
        first[length] = *first;
        heapPlace(first, 0, length, value, before);
      }
      return;
    }
    const auto middle = odyssey_detection_order::partition(first, last, before);
    ideal = (ideal >> 1) + (ideal >> 2);
    if (middle.first - first < last - middle.second) {
      sort(first, middle.first, ideal, before);
      first = middle.second;
    } else {
      sort(middle.second, last, ideal, before);
      last = middle.first;
    }
  }
}
} // namespace odyssey_detection_order

import Foundation

/// Min-heap priority queue
struct PriorityQueue<Element> {
    private var heap: [Element] = []
    private let sort: (Element, Element) -> Bool

    init(sort: @escaping (Element, Element) -> Bool) {
        self.sort = sort
    }

    var isEmpty: Bool { heap.isEmpty }
    var count: Int { heap.count }

    func peek() -> Element? {
        heap.first
    }

    mutating func enqueue(_ element: Element) {
        heap.append(element)
        siftUp(from: heap.count - 1)
    }

    @discardableResult
    mutating func dequeue() -> Element? {
        guard !heap.isEmpty else { return nil }
        if heap.count == 1 {
            return heap.removeLast()
        }
        let first = heap[0]
        heap[0] = heap.removeLast()
        siftDown(from: 0)
        return first
    }

    // MARK: - Heap Operations

    private mutating func siftUp(from index: Int) {
        var child = index
        var parent = (child - 1) / 2
        while child > 0 && sort(heap[child], heap[parent]) {
            heap.swapAt(child, parent)
            child = parent
            parent = (child - 1) / 2
        }
    }

    private mutating func siftDown(from index: Int) {
        var parent = index
        while true {
            let left = 2 * parent + 1
            let right = 2 * parent + 2
            var candidate = parent

            if left < heap.count && sort(heap[left], heap[candidate]) {
                candidate = left
            }
            if right < heap.count && sort(heap[right], heap[candidate]) {
                candidate = right
            }
            if candidate == parent { return }
            heap.swapAt(parent, candidate)
            parent = candidate
        }
    }
}

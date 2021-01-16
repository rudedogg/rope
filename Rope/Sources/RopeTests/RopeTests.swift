//
// Copyright (c) 2019, 2020 David Young.  All rights reserved.
//
import XCTest
@testable import Rope

typealias NSS = Node<Substring>
typealias RSS = Rope<Substring>
typealias ECSS = ExtentController<Substring>

infix operator ⨯: MultiplicationPrecedence

func ⨯<L, R, Lseq : Sequence, Rseq : Sequence>(_ l: Lseq, _ r: Rseq) -> LazySequence<FlattenSequence<LazyMapSequence<Lseq, LazyMapSequence<Rseq, (L, R)>>>>  where Lseq.Element == L, Rseq.Element == R {
	return l.lazy.flatMap({ lelt in r.lazy.map({ relt in (lelt, relt) })})
}

class IndexOrder: XCTestCase {
	func testComparingIndicesSequentially() {
		let rope = Rope<Substring>(content: "pqrstuvwxyz")
		var previous: Rope<Substring>.Index? = nil
		for current in rope.indices {
			guard let p = previous else {
				previous = current
				continue
			}
			XCTAssert(p < current)
			XCTAssert(!(current < p))
			XCTAssert(!(current == p))
		}
	}

	func testComparingIndicesPairwise() {
		let rope = Rope<Substring>(content: "pqrstuvwxyz")
		let indices = rope.indices.enumerated()
		for (l, r) in indices ⨯ indices {
			XCTAssert((l.offset < r.offset) == (l.element < r.element))
		}
	}
}

class ExtentTrails: XCTestCase {
	let ctlr0 = ECSS()
	let ctlr1 = ECSS()
	let ctlr2 = ECSS()
	var _tree: NSS? = nil
	var tree: NSS {
		if let t = _tree {
			return t
		}
		let right: NSS = .extent(under: ctlr1,
		                     .nodes(.text("def"), .extent(under: ctlr2, .text("ghi"))))
		let t: NSS = .extent(under: ctlr0, .nodes(.text("abc"), right))
		_tree = t
		return t
	}
	var _expectations: [[Handle]]? = nil
	var expectations: [[Handle]] {
		if let olde = _expectations {
			return olde
		}
		let newe: [[Handle]] = [[ctlr0],
					[ctlr0],
					[ctlr0],
					[ctlr0, ctlr1],
					[ctlr0, ctlr1],
					[ctlr0, ctlr1],
					[ctlr0, ctlr1, ctlr2],
					[ctlr0, ctlr1, ctlr2],
					[ctlr0, ctlr1, ctlr2],
					[ctlr0, ctlr1, ctlr2]]
		_expectations = newe
		return newe
	}
	let indices: [NodeIndex] = [0, 1, 2, 3, 4, 5, 6, 7, 8, 9].map() { i in
	    NodeIndex(utf16Offset: i)
	}
	func testHandlePaths() {
		for (i, expected) in zip(indices, expectations) {
			XCTAssert(tree.enclosingExtents(at: i) == expected)
		}
	}
}

class WholeRangeUsingRopeIndices: XCTestCase {
	let ctlr = ECSS()
	var _expectations: [NSS]? = nil
	var _r: RSS? = nil
	var r: RSS {
		get {
			if let oldr = _r {
				return oldr
			}
			let newr: RSS = Rope(with: 
			    .nodes(.extent(under: ctlr, .text("abc")),
			           .text("def")))
			_r = newr
			return newr
		}
	}
	func testLookupByRange() {
		XCTAssert(r[r.startIndex..<r.endIndex] ~ r.node)
	}
}

class ExtentsClosing : XCTestCase {
	let simpleCtlr = ECSS()
	let empty: RSS = Rope()
	var _simple: RSS? = nil
	var _cplx: RSS? = nil
	var simple: RSS {
		if let old = _simple {
			return old
		}
		let r: RSS = Rope()
		r.node = .extent(under: simpleCtlr, .empty)
		_simple = r
		return r
	}
	var cplx: RSS {
		if let old = _cplx {
			return old
		}
		let r: RSS = Rope()
		r.node = .extent(under: simpleCtlr, .empty)
		_cplx = r
		return r
	}
	func testClosingEmpty() {
		XCTAssert(empty.extentsClosing(at: empty.startIndex) == [])
		XCTAssert(empty.extentsClosing(at: empty.endIndex) == [])
	}
	func testClosingSimple() {
		let middle = simple.index(after: simple.startIndex)
		XCTAssert(simple.extentsClosing(at: simple.startIndex) == [])
		XCTAssert(simple.extentsClosing(at: middle) == [simpleCtlr])
		// XCTAssert(simple.extentsClosing(at: simple.endIndex) == [simpleCtlr])
	}
}

class EmptyishRopeIndices : XCTestCase {
	var _p: RSS? = nil
	var _one: RSS? = nil
	var _two: RSS? = nil
	var one: RSS {
		get {
			if let old = _one {
				return old
			}
			let new: RSS = Rope(with: .extent(under: ECSS(), .empty))
			_one = new
			return new
		}
	}
	var two: RSS {
		get {
			if let old = _two {
				return old
			}
			let new: RSS = Rope(with:
			    .nodes(.extent(under: ECSS(), .empty),
			           .extent(under: ECSS(), .empty)))
			_two = new
			return new
		}
	}
	let empty: RSS = Rope()
	func testStartIndexEmpty() {
		XCTAssert(empty.startIndex == .end(of: empty))
	}
	func testStartIndexOneEmptyExtent() {
		XCTAssert(one.startIndex == .start(of: one))
		XCTAssert(one.startIndex != one.endIndex)
		XCTAssert(one.index(after: one.startIndex) != one.endIndex)
		XCTAssert(one.index(after: one.index(after: one.startIndex)) ==
		    one.endIndex)
	}
	func testStartIndexTwoEmptyExtents() {
		XCTAssert(two.startIndex == .start(of: two))
		XCTAssert(two.startIndex != two.endIndex)
		XCTAssert(two.index(after: two.startIndex) != two.endIndex)
		XCTAssert(two.index(after: two.index(after: two.startIndex)) !=
		    two.endIndex)
		XCTAssert(two.index(after: two.index(after: two.index(after: two.startIndex))) !=
		    two.endIndex)
		XCTAssert(two.index(after: two.index(after: two.index(after: two.index(after: two.startIndex)))) ==
		    two.endIndex)
	}
}

class ThreeUnitRangesUsingRopeIndices: XCTestCase {
	let ctlr = ECSS()
	var _expectations: [NSS]? = nil
	var _r: RSS? = nil
	var expectations: [NSS] {
		get {
			if let olde = _expectations {
				return olde
			}
			let newe: [NSS] = [
			    .extent(under: ctlr, .text("ab")),
			    .extent(under: ctlr, .text("abc")),
			    .extent(under: ctlr, .text("bc")),
			    .nodes(.extent(under: ctlr, .text("c")),
			         .text("d")),
			    .nodes(.extent(under: ctlr, .empty), .text("de")),
			    .text("def")]
			_expectations = newe
			return newe
		}
	}
	var r: RSS {
		get {
			if let oldr = _r {
				return oldr
			}
			let newr: RSS = Rope(with:
			    .nodes(.extent(under: ctlr, .text("abc")),
			           .text("def")))
			_r = newr
			return newr
		}
	}
	func testLookupByRanges() {
		var prev = r.startIndex
		for (idx, expected) in zip(r.indices.dropFirst(3), expectations) {
			let found = r[prev..<idx]
			prev = r.index(after: prev)
			XCTAssert(found ~ expected, "found \(found) expected \(expected)")
		}
	}
}

class TwoUnitRangesUsingRopeIndices: XCTestCase {
	let ctlr = ECSS()
	var _expectations: [NSS]? = nil
	var _r: RSS? = nil
	var expectations: [NSS] {
		get {
			if let olde = _expectations {
				return olde
			}
			let newe: [NSS] = [
			    .extent(under: ctlr, .text("a")),
			    .extent(under: ctlr, .text("ab")),
			    .extent(under: ctlr, .text("bc")),
			    .extent(under: ctlr, .text("c")),
			    .nodes(.extent(under: ctlr, .empty),
			           .text("d")),
			    .text("de"),
			    .text("ef")]
			_expectations = newe
			return newe
		}
	}
	var r: RSS {
		get {
			if let oldr = _r {
				return oldr
			}
			let newr: RSS = Rope()
			newr.node = .nodes(.extent(under: ctlr, .text("abc")),
			                 .text("def"))
			_r = newr
			return newr
		}
	}
	func testLookupByRanges() {
		var prev = r.startIndex
		for (idx, expected) in zip(r.indices.dropFirst(2), expectations) {
			let found = r[prev..<idx]
			prev = r.index(after: prev)
			XCTAssert(found ~ expected, "found \(found) expected \(expected)")
		}
	}
}

class UnitRangesUsingRopeIndices: XCTestCase {
	let ctlr = ECSS()
	var _expectations: [NSS]? = nil
	var _r: RSS? = nil
	var expectations: [NSS] {
		get {
			if let olde = _expectations {
				return olde
			}
			let newe: [NSS] = [.empty,
			    .extent(under: ctlr, .empty),
			    .extent(under: ctlr, .text("a")),
			    .extent(under: ctlr, .text("b")),
			    .extent(under: ctlr, .text("c")),
			    .extent(under: ctlr, .empty),
			    .text("d"),
			    .text("e"),
			    .text("f")]
			_expectations = newe
			return newe
		}
	}
	var r: RSS {
		get {
			if let oldr = _r {
				return oldr
			}
			let newr: RSS = Rope(with:
			    .nodes(.extent(under: ctlr, .text("abc")),
			           .text("def")))
			_r = newr
			return newr
		}
	}
	func testLookupByRanges() {
		var prev = r.startIndex
		for (idx, expected) in zip(r.indices, expectations) {
			let found = r[prev..<idx]
			prev = idx
			XCTAssert(found == expected, "found \(found) expected \(expected)")
		}
	}
}

class LookupUsingRopeIndicesDerivedFromUTF16Offsets: XCTestCase {
	let ctlr = ECSS()
	var _expectations: [NSS]? = nil
	var _r: RSS? = nil
	var expectations: [NSS] {
		get {
			if let olde = _expectations {
				return olde
			}
			let newe: [NSS] = [
			    .extent(under: ctlr, .text("a")),
			    .extent(under: ctlr, .text("b")),
			    .extent(under: ctlr, .text("c")),
			    .text("d"),
			    .text("e"),
			    .text("f")]
			_expectations = newe
			return newe
		}
	}
	var r: RSS {
		get {
			if let oldr = _r {
				return oldr
			}
			let newr: RSS = Rope(with:
			    .nodes(.extent(under: ctlr, .text("abc")),
			           .text("def")))
			_r = newr
			return newr
		}
	}
	func testIterateElements() {
		for (i, expected) in expectations.enumerated() {
			let idx = RopeIndex(utf16Offset: i, in: r)
			let found = r[idx]
			XCTAssert(found == expected,
			    "found \(found) expected \(expected)")
		}
	}
	func testEndIndex() {
		let idx = RopeIndex(utf16Offset: expectations.count, in: r)
		XCTAssertThrowsError(try r.element(at: idx))
	}
}

class ExtentElementLookupUsingRopeIndices: XCTestCase {
	let ctlr = ECSS()
	var _expectations: [NSS]? = nil
	var _r: RSS? = nil
	var expectations: [NSS] {
		get {
			if let olde = _expectations {
				return olde
			}
			let newe: [NSS] = [.empty,
			    .extent(under: ctlr, .text("a")),
			    .extent(under: ctlr, .text("b")),
			    .extent(under: ctlr, .text("c")),
			    .extent(under: ctlr, .empty),
			    .text("d"),
			    .text("e"),
			    .text("f")]
			_expectations = newe
			return newe
		}
	}
	var r: RSS {
		get {
			if let oldr = _r {
				return oldr
			}
			let newr: RSS = Rope(with:
			    .nodes(.extent(under: ctlr, .text("abc")),
			           .text("def")))
			_r = newr
			return newr
		}
	}
	func testElementsCount() {
		XCTAssert(r.count == expectations.count)
	}
	func testIterateElements() {
		for (found, expected) in zip(r, expectations) {
			XCTAssert(found == expected)
		}
	}
	func testIndicesCount() {
		XCTAssert(r.indices.count == expectations.count)
	}
	func testLookupByIndices() {
		for (idx, expected) in zip(r.indices, expectations) {
			let found = r[idx]
			XCTAssert(found == expected)
		}
	}
	func testStepIndices() {
		var idx = r.startIndex
		idx = r.index(after: idx)
		idx = r.index(after: idx)
		idx = r.index(after: idx)
		idx = r.index(after: idx)
		idx = r.index(after: idx)
		idx = r.index(after: idx)
		idx = r.index(after: idx)
		idx = r.index(after: idx)
		print(idx)
	}
	func testEndIndices() {
		let idx = r.endIndex
		XCTAssertThrowsError(try r.element(at: idx))
	}
}

class BasicElementLookupUsingRopeIndices: XCTestCase {
	let rope1 = Rope<Substring>(content: "abc")
	let rope2 = Rope<Substring>(content: "def")
	func testStartIndices() {
		let idx1 = rope1.startIndex
		let idx2 = rope2.startIndex
		XCTAssert(rope1[idx1].content == "a")
		XCTAssert(rope2[idx2].content == "d")
	}
	func testSecondIndices() {
		let idx1 = rope1.index(after: rope1.startIndex)
		let idx2 = rope2.index(after: rope2.startIndex)
		XCTAssert(rope1[idx1].content == "b")
		XCTAssert(rope2[idx2].content == "e")
	}
	func testThirdIndices() {
		let idx1 = rope1.index(after: rope1.index(after: rope1.startIndex))
		let idx2 = rope2.index(after: rope2.index(after: rope2.startIndex))
		XCTAssert(rope1[idx1].content == "c")
		XCTAssert(rope2[idx2].content == "f")
	}
	func testEndIndices() {
		let idx1 = rope1.endIndex
		let idx2 = rope2.endIndex
		XCTAssertThrowsError(try rope1.element(at: idx1))
		XCTAssertThrowsError(try rope2.element(at: idx2))
	}
}

class CompareDisparateRopeIndices: XCTestCase {
	let rope1 = Rope<Substring>(content: "abc")
	let rope2 = Rope<Substring>(content: "def")
	func testStartIndices() {
		let idx1 = rope1.startIndex
		let idx2 = rope2.startIndex
		XCTAssertThrowsError(try idx1.isLessThan(idx2))
		XCTAssertThrowsError(try idx1.equals(idx2))
	}
	func testSecondIndices() {
		let idx1 = rope1.index(after: rope1.startIndex)
		let idx2 = rope2.index(after: rope2.startIndex)
		XCTAssertThrowsError(try idx1.isLessThan(idx2))
		XCTAssertThrowsError(try idx1.equals(idx2))
	}
	func testEndIndices() {
		let idx1 = rope1.endIndex
		let idx2 = rope2.endIndex
		XCTAssertThrowsError(try idx1.isLessThan(idx2))
		XCTAssertThrowsError(try idx1.equals(idx2))
	}
}

class FibonacciTests : XCTestCase {
	func testFibonacciByIndex() {
		XCTAssert([0, 1, 2, 3, 4, 5].map({ i in fibonacci(index: i)}) == [0, 1, 1, 2, 3, 5])
	}

	func testFibonacciGenerator() {
		// Produce the Fibonacci sequence, 0th through 5th element.
		let arr = Fibonacci(through: 5).reduce([], { (arr: [UInt], elt: UInt) -> [UInt] in arr + [elt]})

		XCTAssert(arr == [0, 1, 1, 2, 3, 5])
	}
}

class HandleHolding : XCTestCase {

/*
	override func setUp() {
		// Put setup code here. This method is called before the invocation of each test method in the class.
	}

	override func tearDown() {
		// Put teardown code here. This method is called after the invocation of each test method in the class.
	}
*/

	/* Test the expectation that if the only remaining reference to an
	 * object is the reference held by a Weak struct,
	 * w, then trying to retrieve the object with w.get() yields nil.
	 */
	func testReleaseHandle() {
		var h = Handle()
		let w = Weak(h)
		h = Handle()
		XCTAssert(w.get() == nil)
	}

	/* Test the expectation that if the only remaining references to an
	 * object are the references held by Weak structs,
	 * w and x, then trying to retrieve the object with w.get() and
	 * x.get() yields nil.
	 */
	func testReleaseTwoHandles() {
		var h = Handle()
		let w = Weak(h)
		let x = Weak(h)
		h = Handle()
		XCTAssert(w.get() == nil)
		XCTAssert(x.get() == nil)
	}

	/* Test the expectation that if there is a second reference to an
	 * object, o, that is also held by a Weak struct, w, then the
	 * object retrieved by w.get() is o.
	 */
	func testHoldHandle() {
		let h = Handle()
		let w = Weak(h)
		XCTAssert(w.get() == h)
	}

	func testStepAndHoldIndex() {
		let first = Node<Substring>(content: "abc")
		let handle = Handle()
		guard case .step(let second) = first.afterStepInsertingIndex(handle) else {
			XCTFail("afterStepInserting failed")
			return
		}
		XCTAssert(second.leaves.map({ (x: Node<Substring>) -> Bool in if case .index(let w) = x { return w.get() == handle } else {return false } })[1])
	}

	func testStepAndReleaseIndex() {
		let first = Node<Substring>(content: "abc")
		var handle = Handle()
		guard case .step(let second) = first.afterStepInsertingIndex(handle) else {
			XCTFail("afterStepInserting failed")
			return
		}
		handle = Handle()
		XCTAssert(!second.leaves.map({ (x: Node<Substring>) -> Bool in if case .index(let w) = x { return w.get() == handle } else {return false } })[1])
	}

	static func isIndex(_ n: Node<Substring>) -> Bool {
		if case .index(_) = n {
			return true
		}
		return false
	}

	static func isNilIndex(_ n: Node<Substring>) -> Bool {
		if case .index(let w) = n {
			return w.get() == nil
		}
		return false
	}

	func testCleanedHoldingIndices() {
		let emptyRope = Rope<Substring>(content: "abcdefghijkl")
		var indices: [Rope<Substring>.Index]? = []

		for i in emptyRope.indices {
			indices?.append(i)
		}
		print(emptyRope.node)
		XCTAssert(emptyRope.node.cleaned()?.leaves.filter(HandleHolding.isIndex).count == 11)
	}

	func testCleanedReleasingIndices() {
		let emptyRope = Rope<Substring>(content: "abcdefghijkl")
		var indices: [Rope<Substring>.Index]? = []

		for i in emptyRope.indices {
			indices?.append(i)
		}
		print(emptyRope.node)
		indices = nil
		XCTAssert(emptyRope.node.cleaned()?.leaves.filter(HandleHolding.isIndex).count == 0)
	}

	func testReleasingIndices() {
		let rope = Rope<Substring>(content: "abcdefghijkl")
		var indices: [Rope<Substring>.Index]? = []

		for i in rope.indices {
			indices?.append(i)
		}

		indices = nil
		print(rope.node.leaves)
		print(rope.node.leaves.filter(HandleHolding.isNilIndex))

		XCTAssert(rope.node.leaves.filter(HandleHolding.isNilIndex).count == 11)
	}

	func testPerformanceExample() {
		// This is an example of a performance test case.
		self.measure {
			// Put the code you want to measure the time of here.
		}
	}
}

class NodeSubropes : XCTestCase {
	let n: NSS = .nodes(.text("abc"), .text("defgh"), .text("ijkl"))

	func testFullContent() {
		XCTAssert(n.content == "abcdefghijkl")
	}

	func testLeadingSubnode() {
		XCTAssert(n.subrope(from: NodeIndex(utf16Offset: 0), to: NodeIndex(utf16Offset: 3)).content == "abc")
	}

	func testCrossingFirstTwoSubnodes() {
		XCTAssert(n.subrope(from: NodeIndex(utf16Offset: 0), to: NodeIndex(utf16Offset: 5)).content == "abcde")
	}

	func testSecondSubnode() {
		XCTAssert(n.subrope(from: NodeIndex(utf16Offset: 3), to: NodeIndex(utf16Offset: 8)).content == "defgh")
	}

	func testTrailingTwoSubnodes() {
		XCTAssert(n.subrope(from: NodeIndex(utf16Offset: 3), to: NodeIndex(utf16Offset: 12)).content == "defghijkl")
	}

	func testCrossingLastTwoSubnodes() {
		XCTAssert(n.subrope(from: NodeIndex(utf16Offset: 4), to: NodeIndex(utf16Offset: 9)).content == "efghi")
	}
}

class NodeAttributes : XCTestCase {
	typealias Key = NSAttributedString.Key
	static let frontAttrs: Attributes = [Key.cursor : true]
	static let middleAttrs: Attributes = [Key.expansion : true]
	static let backAttrs: Attributes = [Key.font : true]
	static let newAttrs: Attributes = [Key.cursor : false, Key.font : false]
	static let abc: NSS = .text("abc", attributes: frontAttrs)
	static let defgh: NSS = .text("defgh", attributes: middleAttrs)
	static let ijkl: NSS = .text("ijkl", attributes: backAttrs)
	let n: NSS = .nodes(abc, defgh, ijkl)

	static func frontAttrsEqual(_ attrs: Attributes) -> Bool {
		guard attrs.count == 1 else {
			return false
		}
		guard let val = attrs[Key.cursor] as? Bool else {
			return false
		}
		return val
	}
	static func middleAttrsEqual(_ attrs: Attributes) -> Bool {
		guard attrs.count == 1 else {
			return false
		}
		guard let val = attrs[Key.expansion] as? Bool else {
			return false
		}
		return val
	}
	static func backAttrsEqual(_ attrs: Attributes) -> Bool {
		guard attrs.count == 1 else {
			return false
		}
		guard let val = attrs[Key.font] as? Bool else {
			return false
		}
		return val
	}
	static func newAttrsEqual(_ attrs: Attributes) -> Bool {
		guard attrs.count == 2 else {
			return false
		}
		guard let font = attrs[Key.font] as? Bool else {
			return false
		}
		guard !font else {
			return false
		}
		guard let cursor = attrs[Key.cursor] as? Bool else {
			return false
		}
		return !cursor
	}

	func testFrontAttributes() {
		let (attrs, range) = n.attributes(at: NodeIndex.start)
		XCTAssert(NodeAttributes.frontAttrsEqual(attrs))
		XCTAssert(range == NodeIndex.utf16RangeTo(3))
	}
	func testMiddleAttributes() {
		let (attrs, range) = n.attributes(at: NodeIndex(utf16Offset: 3))
		XCTAssert(NodeAttributes.middleAttrsEqual(attrs))
		XCTAssert(range == NodeIndex.utf16Range(3..<8))
	}
	func testBackAttributes() {
		let (attrs, range) = n.attributes(at: NodeIndex(utf16Offset: 8))
		XCTAssert(NodeAttributes.backAttrsEqual(attrs))
		XCTAssert(range == NodeIndex.utf16Range(8..<12))
	}
	func testLastAttributes() {
		let (attrs, range) = n.attributes(at: NodeIndex(utf16Offset: 11))
		XCTAssert(NodeAttributes.backAttrsEqual(attrs))
		XCTAssert(range == NodeIndex.utf16Range(8..<12))
	}
	func testSettingFrontAndMiddleAttributes() {
		let newn = n.settingAttributes(NodeAttributes.newAttrs,
		    range: NodeIndex.utf16Range(0..<8))
		let (attrs, frontRange) = newn.attributes(at: NodeIndex(utf16Offset: 0))
		XCTAssert(NodeAttributes.newAttrsEqual(attrs))
		XCTAssert(frontRange == NodeIndex.utf16Range(0..<3))
		let (_, middleRange) = newn.attributes(at: NodeIndex(utf16Offset: 3))
		XCTAssert(middleRange == NodeIndex.utf16Range(3..<8))
	}
	static func helpTestSettingCentralAttributes(_ oldn: NSS) {
		let newn = oldn.settingAttributes(NodeAttributes.newAttrs,
		    range: NodeIndex.utf16Range(2..<9))

		let (frontAttrs, frontRange) =
		    newn.attributes(at: NodeIndex(utf16Offset: 0))
		XCTAssert(frontRange == NodeIndex.utf16Range(0..<2))
		XCTAssert(NodeAttributes.frontAttrsEqual(frontAttrs))

		let (midAttrs1, midRange1) =
		    newn.attributes(at: NodeIndex(utf16Offset: 2))
		XCTAssert(midRange1 == NodeIndex.utf16Range(2..<3))
		XCTAssert(NodeAttributes.newAttrsEqual(midAttrs1))

		let (midAttrs2, midRange2) =
		    newn.attributes(at: NodeIndex(utf16Offset: 3))
		XCTAssert(midRange2 == NodeIndex.utf16Range(3..<8))
		XCTAssert(NodeAttributes.newAttrsEqual(midAttrs2))

		let (midAttrs3, midRange3) =
		    newn.attributes(at: NodeIndex(utf16Offset: 8))
		XCTAssert(midRange3 == NodeIndex.utf16Range(8..<9))
		XCTAssert(NodeAttributes.newAttrsEqual(midAttrs3))

		let (backAttrs, backRange) =
		    newn.attributes(at: NodeIndex(utf16Offset: 9))
		XCTAssert(backRange == NodeIndex.utf16Range(9..<12))
		XCTAssert(NodeAttributes.backAttrsEqual(backAttrs))
	}
	func testSettingCentralAttributes() {
		NodeAttributes.helpTestSettingCentralAttributes(n)
	}
	func testSettingCentralAttributesWithCursor() {
		let ctlr = ECSS()
		let contn: NSS = .extent(under: ctlr, n)
		NodeAttributes.helpTestSettingCentralAttributes(contn)
	}
	func testSettingCentralAttributesWithExtent() {
		let ctlr = ECSS()
		let contn: NSS = .extent(under: ctlr, n)
		NodeAttributes.helpTestSettingCentralAttributes(contn)
	}
	func testSettingBackAttributes() {
		let newn = n.settingAttributes(NodeAttributes.newAttrs,
		    range: NodeIndex.utf16Range(8..<12))
		let (attrs, range) = newn.attributes(at: NodeIndex(utf16Offset: 8))
		XCTAssert(NodeAttributes.newAttrsEqual(attrs))
		XCTAssert(range == NodeIndex.utf16Range(8..<12))
	}
	func testSettingLastAttributes() {
		let newn = n.settingAttributes(NodeAttributes.newAttrs,
		    range: NodeIndex.utf16Range(11..<12))
		let (attrs, range) = newn.attributes(at: NodeIndex(utf16Offset: 11))
		XCTAssert(NodeAttributes.newAttrsEqual(attrs))
		XCTAssert(range == NodeIndex.utf16Range(11..<12))
		let (_, abuttingRange) = newn.attributes(at: NodeIndex(utf16Offset: 8))
		XCTAssert(abuttingRange == NodeIndex.utf16Range(8..<11))
	}
}

class AppendInsertRemoveReplace : XCTestCase {
	func testReplace() {
		
		// let rope = Rope<Substring>(content: "This is the original content.")
		let str: String = "This is the original content."
	
		print(str.firstIndex(of: " is") ?? -1)
	}
}

class HandleSets : XCTestCase {
	func testInit() {
		let set = HandleSet()
		XCTAssert(set.cursorCount == 0)
		XCTAssert(set.extentCount == 0)
		XCTAssert(set.indexCount == 0)
	}
	func testSeqInit() {
		let ids: [Handle.Id] = [.cursor(0), .extent(1), .index(2)]
		let set = HandleSet(ids)
		XCTAssert(set.cursorCount == 1)
		XCTAssert(set.extentCount == 1)
		XCTAssert(set.indexCount == 1)
	}
	func testLiteralInit() {
		let set: [HandleSet] = [[.cursor(0), .extent(0), .index(0)],
		                         [.cursor(0), .extent(0), .index(0),
					  .index(1)],
		                         [.cursor(0), .cursor(1), .extent(0),
					  .index(0)],
		                         [.cursor(0), .extent(0), .extent(1),
					  .index(0)]]
		XCTAssert(set[0].cursorCount == 1)
		XCTAssert(set[0].extentCount == 1)
		XCTAssert(set[0].indexCount == 1)
		XCTAssert(set[1].cursorCount == 1)
		XCTAssert(set[1].extentCount == 1)
		XCTAssert(set[1].indexCount == 2)
		XCTAssert(set[2].cursorCount == 2)
		XCTAssert(set[2].extentCount == 1)
		XCTAssert(set[2].indexCount == 1)
		XCTAssert(set[3].cursorCount == 1)
		XCTAssert(set[3].extentCount == 2)
		XCTAssert(set[3].indexCount == 1)
	}
	func testUnion() {
		let set: [HandleSet] = [[.cursor(0), .extent(0), .index(0)],
		                         [.cursor(0), .extent(0), .index(0),
					  .index(1)],
		                         [.cursor(0), .cursor(1), .extent(0),
					  .index(0)],
		                         [.cursor(0), .extent(0), .extent(1),
					  .index(0)]]
		XCTAssert(set[0].union(set[1]).cursorCount == 1)
		XCTAssert(set[0].union(set[1]).extentCount == 1)
		XCTAssert(set[0].union(set[1]).indexCount == 2)
		XCTAssert(set[1].union(set[2]).cursorCount == 2)
		XCTAssert(set[1].union(set[2]).extentCount == 1)
		XCTAssert(set[1].union(set[2]).indexCount == 2)
		XCTAssert(set[2].union(set[3]).cursorCount == 2)
		XCTAssert(set[2].union(set[3]).extentCount == 2)
		XCTAssert(set[2].union(set[3]).indexCount == 1)
		var p = set[0], q = set[1]
		p.formUnion(q)
		XCTAssert(p.cursorCount == 1)
		XCTAssert(p.extentCount == 1)
		XCTAssert(p.indexCount == 2)
	}
	func testIntersection() {
		let overlap: [HandleSet] = [[.cursor(0), .extent(0), .index(0)],
		                         [.cursor(0), .extent(0), .index(0),
					  .index(1)],
		                         [.cursor(0), .cursor(1), .extent(0),
					  .index(0)],
		                         [.cursor(0), .extent(0), .extent(1),
					  .index(0)]]

		XCTAssert(overlap[0].intersection(overlap[1]).cursorCount == 1)
		XCTAssert(overlap[0].intersection(overlap[1]).extentCount == 1)
		XCTAssert(overlap[0].intersection(overlap[1]).indexCount == 1)
		XCTAssert(overlap[1].intersection(overlap[2]).cursorCount == 1)
		XCTAssert(overlap[1].intersection(overlap[2]).extentCount == 1)
		XCTAssert(overlap[1].intersection(overlap[2]).indexCount == 1)
		XCTAssert(overlap[2].intersection(overlap[3]).cursorCount == 1)
		XCTAssert(overlap[2].intersection(overlap[3]).extentCount == 1)
		XCTAssert(overlap[2].intersection(overlap[3]).indexCount == 1)

		let disj: [HandleSet] = [[.cursor(0), .extent(0), .index(0)],
		                         [.cursor(4), .extent(4), .index(4),
					  .index(8)],
		                         [.cursor(8), .cursor(12), .extent(8),
					  .index(12)],
		                         [.cursor(16), .extent(12), .extent(16),
					  .index(16)]]

		XCTAssert(disj[0].intersection(disj[1]).cursorCount == 0)
		XCTAssert(disj[0].intersection(disj[1]).extentCount == 0)
		XCTAssert(disj[0].intersection(disj[1]).indexCount == 0)
		XCTAssert(disj[1].intersection(disj[2]).cursorCount == 0)
		XCTAssert(disj[1].intersection(disj[2]).extentCount == 0)
		XCTAssert(disj[1].intersection(disj[2]).indexCount == 0)
		XCTAssert(disj[2].intersection(disj[3]).cursorCount == 0)
		XCTAssert(disj[2].intersection(disj[3]).extentCount == 0)
		XCTAssert(disj[2].intersection(disj[3]).indexCount == 0)
	}
	func testSymmetricDifference() {
		let overlap: [HandleSet] = [
		    [.cursor(0), .extent(0), .index(0)],		// 0
		    [.cursor(0), .extent(0), .index(0), .index(1)],	// 1
		    [.cursor(0), .cursor(1), .extent(0), .index(0)],	// 2
		    [.cursor(0), .extent(0), .extent(1), .index(0)]]	// 3

		let diff0 = overlap[0].symmetricDifference(overlap[1])
		XCTAssert(diff0.cursorCount == 0)
		XCTAssert(diff0.extentCount == 0)
		XCTAssert(diff0.indexCount == 1)

		let diff1 = overlap[1].symmetricDifference(overlap[2])
		XCTAssert(diff1.cursorCount == 1)
		XCTAssert(diff1.extentCount == 0)
		XCTAssert(diff1.indexCount == 1)

		let diff2 = overlap[2].symmetricDifference(overlap[3])
		XCTAssert(diff2.cursorCount == 1)
		XCTAssert(diff2.extentCount == 1)
		XCTAssert(diff2.indexCount == 0)

		let disj: [HandleSet] = [
		    [.cursor(0), .extent(0), .index(0)],		// 0
		    [.cursor(4), .extent(4), .index(4), .index(8)],	// 1
		    [.cursor(8), .cursor(12), .extent(8), .index(12)],	// 2
		    [.cursor(16), .extent(12), .extent(16), .index(16)]]// 3

		let diff3 = disj[0].symmetricDifference(disj[1])

		XCTAssert(diff3.cursorCount == 2)
		XCTAssert(diff3.extentCount == 2)
		XCTAssert(diff3.indexCount == 3)

		let diff4 = disj[1].symmetricDifference(disj[2])

		XCTAssert(diff4.cursorCount == 3)
		XCTAssert(diff4.extentCount == 2)
		XCTAssert(diff4.indexCount == 3)

		let diff5 = disj[2].symmetricDifference(disj[3])

		XCTAssert(diff5.cursorCount == 3)
		XCTAssert(diff5.extentCount == 3)
		XCTAssert(diff5.indexCount == 2)
	}
	func testInsert() {
		var set: HandleSet = [.cursor(0)]

		XCTAssert(set.cursorCount == 1)
		XCTAssert(set.insert(.cursor(0)) == (false, .cursor(0)))
		XCTAssert(set.cursorCount == 1)
		XCTAssert(set.insert(.cursor(1)) == (true, .cursor(1)))
		XCTAssert(set.cursorCount == 2)
		XCTAssert(set.extentCount == 0)
		XCTAssert(set.indexCount == 0)
	}
	func testRemove() {
		var set: HandleSet = [.cursor(0)]

		XCTAssert(set.cursorCount == 1)
		XCTAssert(set.remove(.cursor(1)) == nil)
		XCTAssert(set.cursorCount == 1)
		XCTAssert(set.remove(.cursor(0)) == .cursor(0))
		XCTAssert(set.cursorCount == 0)
		XCTAssert(set.extentCount == 0)
		XCTAssert(set.indexCount == 0)
	}
	func testUpdate() {
		var set: HandleSet = [.cursor(0)]

		XCTAssert(set.cursorCount == 1)
		XCTAssert(set.update(with: .cursor(0)) == .cursor(0))
		XCTAssert(set.cursorCount == 1)
		XCTAssert(set.update(with: .cursor(1)) == nil)
		XCTAssert(set.cursorCount == 2)
		XCTAssert(set.extentCount == 0)
		XCTAssert(set.indexCount == 0)
	}
}

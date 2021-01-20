//
// Copyright (c) 2019, 2020 David Young.  All rights reserved.
//
import Foundation

enum RopeNoSuchElement : Error {
case onInterior
case atStart
case atEnd
}

/* Use cases:
 *
 * Get/set/add/remove attributes on characters.
 *
 * Get/set/add/remove attributes on a cursor.
 *
 * Enclose a range in an extent.  The range must be
 * well-formed: must begin and end inside the same extent. 
 *
 * Insert a cursor between characters or nested between extents.
 *
 * Remove a cursor.
 *
 * "Step" a cursor left or right by a character.
 *
 * "Scoot" a cursor left or right by an extent boundary.
 *
 * "Scoot" a cursor left or right by a cursor?
 *
 * Replace a cursor by an extent; apply the cursor's attributes to
 * the extent's content.
 *
 * Insert some text left of a cursor; apply the cursor's attributes
 * to the text.
 */
public class Rope<C : Content> : Collection {
	public enum Climb {
	case `in`
	case out
	}
	public typealias Content = C
	public typealias Element = Node<C>
	public typealias Index = RopeIndex<C>
	private var top: Node<C>
	public var generation: UInt64 = 0
	public var startIndex: Index {
		/* There are at least three index positions, start and
		 * end, if there is even a solitary extent.  Need to return
		 * .start(of: self) in that case.
		 */
		if top.startIndex == top.endIndex && top.hids.extentCount == 0 {
			return .end(of: self)
		}
		return .start(of: self)
	}
	public var endIndex: Index { return .end(of: self) }

	public init() {
		top = .empty
	}
	public var node: Node<C> {
		get {
			return top
		}
		set {
			top = newValue
		}
	}
	public func containsIndex(_ h1: Handle, before h2: Handle) -> Bool {
		return top.containsHandle(h1, before: h2)
	}
	public init<T>(content t: T) where C : Initializable,
	    C.Initializer == T, T : Collection {
		top = Node(content: t)
	}
	public func index(after i: Index) -> Index {
		guard i.owner === self else {
			fatalError("Mismatched owner")
		}
		switch i {
		case .start(_):
			let h = Handle()
			guard case .step(let n) =
			    top.inserting(h, after: .rightStep) else {
				return .end(of: self)
			}
			top = n
			return .interior(of: self, at: generation,
			                 index: 0, handle: h)
		case .end(_):
			fatalError("No index after .endIndex")
		case .interior(_, _, let m, let h):
			let j = Handle()
			switch top.inserting(j, one: .rightStep, after: h) {
			case .inchOut:
				fatalError(
				    ".interior(\(m), \(h)) already at end?")
			case .absent:
				fatalError(
				    ".interior(\(m), \(h)) is absent")
			case .stepOut:
				return .end(of: self)
			case .step(let node):
				top = node
				return .interior(of: self,
				                 at: generation,
						 index: m + 1,
						 handle: j)
			}
		}
	}
	public func index(after i: Index, climbing dir: Climb) -> Index? {
		if case .end(_) = i {
			return nil
		}
		let j = index(after: i)
		switch (enclosingExtents(at: i)?.count,
			dir,
		        enclosingExtents(at: j)?.count) {
		case (let ni?, .in, let nj?) where ni < nj:
			return j
		case (let ni?, .out, let nj?) where ni > nj:
			return j
		default:
			return nil
		}
	}
	public func index(before i: Index, climbing dir: Climb) -> Index? {
		if case .start(_) = i {
			return nil
		}
		let j = index(before: i)
		switch (enclosingExtents(at: i)?.count,
			dir,
		        enclosingExtents(at: j)?.count) {
		case (let ni?, .in, let nj?) where ni < nj:
			return j
		case (let ni?, .out, let nj?) where ni > nj:
			return j
		default:
			return nil
		}
	}
	public func index(before i: Index) -> Index {
		guard i.owner === self else {
			fatalError("Mismatched owner")
		}
		switch i {
		case .start(_):
			fatalError("No index before .startIndex")
		case .end(_):
			let h = Handle()
			guard case .step(let n) =
			    top.inserting(h, after: .leftStep) else {
				return .start(of: self)
			}
			top = n
			return .interior(of: self, at: generation,
			                 index: 0, handle: h)
		case .interior(_, _, let m, let h):
			let j = Handle()
			switch top.inserting(j, one: .leftStep, after: h) {
			case .inchOut:
				fatalError(
				    ".interior(\(m), \(h)) already at start?")
			case .absent:
				fatalError(
				    ".interior(\(m), \(h)) is absent")
			case .stepOut:
				return .start(of: self)
			case .step(let node):
				top = node
				return .interior(of: self,
				                 at: generation,
						 index: m + 1,
						 handle: j)
			}
		}
	}
	/* TBD tests */
	public subscript(_ r: Range<NodeIndex>) -> Content {
		set(newValue) {
			top = top.replacing(range: r, with: newValue)
		}
		get {
			return top[r]
		}
	}
/*
	public subscript<I>(_ r: Range<NodeIndex>) -> I
                where C : Initializable, C.Initializer == I, I : Collection, I : Initializable, I.Initializer == C {
		set(newValue) {
			top = top.replacing(range: r, with: C(newValue))
		}
		get {
			return I(top[r])
		}
	}
*/
	public subscript(i: NodeIndex) -> Content.Element {
		return top.element(at: i)
	}
	public subscript(r: Range<Index>) -> Element {
		get {
			guard let e = top.subrope(from: r.lowerBound,
			    to: r.upperBound) else {
				fatalError("No such range")
			}
			return e
		}
	}
	public subscript(i: Index) -> Element {
		get {
			do {
				return try element(at: i)
			} catch {
				fatalError("No such element")
			}
		}
	}
	public func element(at i: Index) throws -> Element {
		switch i {
		case .start(_):
			guard case .step(let node) = top.firstElement()
			    else {
				throw RopeNoSuchElement.atStart
			}
			return node
		case .interior(_, _, _, let h):
			let result = top.element(at: h)
			guard case .step(let node) = result else {
				throw RopeNoSuchElement.onInterior
			}
			return node
		case .end(_):
			throw RopeNoSuchElement.atEnd
		}
	}
	public func insert(_ elt: Element, at i: Index) {
		guard self === i.owner else {
			fatalError("Invalid index")
		}
		if case .empty = elt {
			fatalError("You may not insert .empty")
		}
		switch i {
		case .start(_):
			top = .nodes(elt, top)
		case .end(_):
			top = .nodes(top, elt)
		case .interior(_, _, _, let h):
			top = top.inserting(elt, at: h)
		}
	}
	public func attributes(at i: NodeIndex)
	    -> (Attributes, Range<NodeIndex>) {
		return top.attributes(at: i)
	}
	public func setAttributes(_ attrs: Attributes, range: Range<NodeIndex>){
		top = top.settingAttributes(attrs, range: range)
	}
	public func clearAttributesOnRange(_ range: Range<NodeIndex>) {
		top = top.clearingAttributes(range: range)
	}
}

extension Rope {
	public convenience init(with node: Node<C>) {
		self.init()
		top = node
	}
}

extension Rope {
        public struct UTF16View {
		let rope: Rope<C>
		init(rope r: Rope<C>) {
			rope = r
		}
                public subscript(i: NodeIndex) -> Unicode.UTF16.CodeUnit {
                        get {
                                return rope.top.utf16(at: i)
                        }
                }
		public var length: Int {
			return rope.top.length
		}
	}
	public var utf16: UTF16View {
                return UTF16View(rope: self)
	}
}

extension Rope {
	func enclosingExtents(at i: RopeIndex<C>) -> [ExtentController<C>]? {
		return top.enclosingExtents(at: i)
	}
	public func extentsClosing(at i: RopeIndex<C>)
	    -> [ExtentController<C>]? {
		return top.extentsClosing(at: i)
	}
	public func extentsOpening(at i: RopeIndex<C>)
	    -> [ExtentController<C>]? {
		return top.extentsOpening(at: i)
	}
}

/*
extension Rope : ExpressibleByStringLiteral,
    ExpressibleByExtendedGraphemeClusterLiteral where
    Rope.Content : ExpressibleByStringLiteral {
	public init(stringLiteral s: S) {
		top = Node<Content>(content: s)
	}
}
*/

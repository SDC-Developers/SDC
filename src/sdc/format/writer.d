module sdc.format.writer;

import sdc.format.chunk;

struct Writer {
	import std.array;
	Appender!string buffer;
	
	string write(Chunk[] chunks) {
		import std.array;
		buffer = appender!string();
		
		uint cost = 0;
		size_t start = 0;
		foreach (i, c; chunks) {
			if (!c.endsBreakableLine()) {
				continue;
			}
			
			cost += Splitter(&this, chunks[start .. i]).write();
			start = i;
		}
		
		// Make sure we write the last line too.
		cost += Splitter(&this, chunks[start .. $]).write();
		
		return buffer.data;
	}
}

enum INDENTATION_SIZE = 4;
enum PAGE_WIDTH = 80;
enum MAX_ATTEMPT = 5000;

import std.container.rbtree;
alias SolveStateQueue = RedBlackTree!SolveState;

struct Splitter {
	Writer* writer;
	Chunk[] line;
	
	this(Writer* writer, Chunk[] line) {
		this.writer = writer;
		this.line = line;
	}
	
	uint write() {
		if (line.length == 0) {
			// This is empty.
			return 0;
		}
		
		auto best = findBestState();
		return LineWriter(best, writer.buffer).write();
	}
	
	SolveState findBestState() {
		auto best = SolveState(&this);
		if (best.overflow == 0) {
			return best;
		}
		
		uint attempts = 0;
		scope queue = redBlackTree(best);
		
		// Once we have a solution that fits, or no more things
		// to try, then we are done.
		while (!queue.empty) {
			auto candidate = queue.front;
			queue.removeFront();
			
			if (candidate.isDeadSubTree(best)) {
				continue;
			}
			
			if (candidate.isBetterThan(best)) {
				best = candidate;
				if (candidate.overflow == 0) {
					// We found the lowest cost solution that fit on the page.
					break;
				}
			}
			
			// We ran out of attempts.
			if (attempts++ > MAX_ATTEMPT) {
				break;
			}
			
			candidate.expand(queue);
		}
		
		return best;
	}
}

struct SolveState {
	uint sunk = 0;
	uint overflow = 0;
	uint cost = 0;
	
	Splitter* splitter;
	uint[] ruleValues;
	
	// The set of free to bind rules that affect the next overflowing line.
	RedBlackTree!uint liveRules;
	
	// Span that require indentation.
	RedBlackTree!Span usedSpans;
	
	this(Splitter* splitter, uint[] ruleValues = []) {
		this.splitter = splitter;
		this.ruleValues = ruleValues;
		computeCost();
	}
	
	void computeCost() {
		sunk = 0;
		overflow = 0;
		cost = 0;
		
		// If there is nothing to be done, just skip.
		auto line = splitter.line;
		if (line.length == 0) {
			return;
		}
		
		foreach (uint i, ref c; line[1 .. $]) {
			if (c.span is null) {
				continue;
			}
			
			if (!isSplit(i + 1)) {
				continue;
			}
			
			if (usedSpans is null) {
				usedSpans = redBlackTree!Span();
			}
			
			usedSpans.insert(c.span);
		}
		
		// All the span which do not fit on one line.
		RedBlackTree!Span brokenSpans;
		
		uint length = 0;
		uint start = 0;
		
		uint previousIndentLength = 0;
		Span previousSpan = null;
		
		void endLine(uint i) {
			if (length <= PAGE_WIDTH) {
				return;
			}
			
			uint lineOverflow = length - PAGE_WIDTH;
			overflow += lineOverflow;
			
			// We try to split element in the first line that overflows.
			if (liveRules !is null) {
				return;
			}
			
			import std.algorithm.comparison, std.range;
			auto range = max(cast(uint) ruleValues.length, start + 1).iota(i);
			
			// If the line overflow, but has no split point, it is sunk.
			if (range.empty) {
				sunk += lineOverflow;
				return;
			}
			
			liveRules = redBlackTree(range);
		}
		
		void startLine(uint i) {
			start = i;
			
			auto indentLength = INDENTATION_SIZE * (line[i].indentation + getIndent(i));
			auto span = line[i].span;
			scope(success) {
				previousIndentLength = indentLength;
				previousSpan = span;
			}
			
			bool needInsert = true;
			
			// Make sure to keep track of the span that cross over line breaks.
			while (span !is null && needInsert) {
				scope(success) span = span.parent;
				
				if (brokenSpans is null) {
					brokenSpans = redBlackTree!Span();
				}
				
				needInsert = brokenSpans.insert(span) > 0;
			}
			
			/**
			 * We want to avoid sequential lines having the same indentation
			 * but for different reasons. For instance:
			 * function(first(
			 *     argument), second(
			 *     another);
			 *
			 * It is impossible to prevent in the general case,
			 * but we can (and do) penalize it.
			 */
			if (indentLength > 0 && indentLength == previousIndentLength && span !is previousSpan) {
				cost += 1000;
			}
			
			length = indentLength + line[i].length;
		}
		
		void newLine(uint i) {
			endLine(i);
			startLine(i);
		}
		
		startLine(0);
		
		foreach (uint i, ref c; line[1 .. $]) {
			if (isSplit(i + 1)) {
				newLine(i + 1);
				
				// FIXME: compute proper cost.
				cost += 1;
				continue;
			}
			
			if (c.splitType == SplitType.Space) {
				length++;
			}
			
			length += c.length;
		}
		
		endLine(cast(uint) line.length);
		
		// Account for the cost of breaking spans.
		if (brokenSpans !is null) {
			foreach (s; brokenSpans) {
				cost += s.cost;
			}
		}
	}
	
	uint getRuleValue(uint i) const {
		return (i - 1) < ruleValues.length
			? ruleValues[i - 1]
			: 0;
	}
	
	bool isSplit(uint i) const {
		auto st = splitter.line[i].splitType;
		return st == SplitType.TwoNewLines || st == SplitType.NewLine || getRuleValue(i) > 0;
	}
	
	uint getIndent(uint i) {
		if (usedSpans is null) {
			return 0;
		}
		
		uint indent = 0;
		
		auto span = splitter.line[i].span;
		while (span !is null) {
			scope(success) span = span.parent;
			
			if (span in usedSpans) {
				indent += span.indent;
			}
		}
		
		return indent;
	}
	
	SolveState withRuleValue(uint i, uint v) in {
		assert(i > ruleValues.length);
	} body {
		uint[] newRuleValues = ruleValues;
		newRuleValues.length = i;
		newRuleValues[i - 1] = v;
		
		return SolveState(splitter, newRuleValues);
	}
	
	void expand()(SolveStateQueue queue) {
		if (liveRules is null) {
			return;
		}
		
		foreach (r; liveRules) {
			queue.insert(withRuleValue(r, 1));
		}
	}
	
	// Return if this solve state must be chosen over rhs as a solution.
	bool isDeadSubTree(const ref SolveState best) const {
		if (sunk > best.overflow) {
			// We already have comitted to an overflow greater than the best.
			return true;
		}
		
		if (sunk == best.overflow && cost >= best.cost) {
			// We already comitted to a cost greater than the best.
			return true;
		}
		
		// There is still hope to find a better solution down that path.
		return false;
	}
	
	// Return if this solve state must be chosen over rhs as a solution.
	bool isBetterThan(const ref SolveState rhs) const {
		if (overflow < rhs.overflow) {
			return true;
		}
		
		if (overflow == rhs.overflow && cost < rhs.cost) {
			return true;
		}
		
		return false;
	}
	
	// lhs < rhs => rhs.opCmp(rhs) < 0
	int opCmp(const ref SolveState rhs) const {
		if (cost != rhs.cost) {
			return cost - rhs.cost;
		}
		
		if (overflow != rhs.overflow) {
			return overflow - rhs.overflow;
		}
		
		if (sunk != rhs.sunk) {
			return sunk - rhs.sunk;
		}
		
		return opCmpSlow(rhs);
	}
	
	int opCmpSlow(const ref SolveState rhs) const {
		// Explore candidate with a lot of follow up first.
		if (ruleValues.length != rhs.ruleValues.length) {
			return cast(int) (ruleValues.length - rhs.ruleValues.length);
		}
		
		foreach (i; 0 .. ruleValues.length) {
			if (ruleValues[i] != rhs.ruleValues[i]) {
				return rhs.ruleValues[i] - ruleValues[i];
			}
		}
		
		return 0;
	}
}

struct LineWriter {
	SolveState state;
	
	import std.array;
	Appender!string buffer;
	
	this(SolveState state, Appender!string buffer) {
		this.state = state;
		this.buffer = buffer;
	}
	
	uint write() {
		auto line = state.splitter.line;
		assert(line.length > 0, "line must not be empty");
		
		foreach (uint i, c; line) {
			assert((i == 0) || !c.endsBreakableLine(), "Line splitting bug");
			
			if (state.isSplit(i)) {
				if (c.splitType == SplitType.TwoNewLines) {
					output("\n\n");
				} else {
					output('\n');
				}
				
				indent(c.indentation + state.getIndent(i));
			} else if (c.splitType == SplitType.Space) {
				output(' ');
			}
			
			output(c.text);
		}
		
		return state.cost;
	}
	
	void output(char c) {
		buffer ~= c;
	}
	
	void output(string s) {
		buffer ~= s;
	}
	
	void indent(uint level) {
		foreach (_; 0 .. level) {
			output('\t');
		}
	}
}

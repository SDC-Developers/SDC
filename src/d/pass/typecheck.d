/**
 * This module crawl the AST to check types.
 * In the process unknown types are resolved
 * and type related operations are processed.
 */
module d.pass.typecheck;

import d.pass.base;

import d.ast.declaration;
import d.ast.dmodule;
import d.ast.dscope;
import d.ast.identifier;

import std.algorithm;
import std.array;

auto typeCheck(Module m) {
	auto pass = new TypecheckPass();
	
	return pass.visit(m);
}

import d.ast.expression;
import d.ast.declaration;
import d.ast.statement;
import d.ast.type;

class TypecheckPass {
	private DeclarationVisitor declarationVisitor;
	private StatementVisitor statementVisitor;
	private ExpressionVisitor expressionVisitor;
	private TypeVisitor typeVisitor;
	
	private SizeofCalculator sizeofCalculator;
	
	private Type returnType;
	private Type thisType;
	
	this() {
		declarationVisitor	= new DeclarationVisitor(this);
		statementVisitor	= new StatementVisitor(this);
		expressionVisitor	= new ExpressionVisitor(this);
		typeVisitor			= new TypeVisitor(this);
		sizeofCalculator	= new SizeofCalculator(this);
	}
	
final:
	Module visit(Module m) {
		foreach(decl; m.declarations) {
			visit(decl);
		}
		
		return m;
	}
	
	auto visit(Declaration decl) {
		return declarationVisitor.visit(decl);
	}
	
	auto visit(Statement stmt) {
		return statementVisitor.visit(stmt);
	}
	
	auto visit(Expression e) {
		return expressionVisitor.visit(e);
	}
	
	auto visit(Type t) {
		return typeVisitor.visit(t);
	}
}

import d.ast.adt;
import d.ast.dfunction;

class DeclarationVisitor {
	private TypecheckPass pass;
	alias pass this;
	
	this(TypecheckPass pass) {
		this.pass = pass;
	}
	
final:
	Declaration visit(Declaration d) {
		return this.dispatch(d);
	}
	
	Symbol visit(FunctionDefinition fun) {
		// Prepare statement visitor for return type.
		auto oldReturnType = returnType;
		scope(exit) returnType = oldReturnType;
		
		returnType = fun.returnType = pass.visit(fun.returnType);
		
		// TODO: move that into an ADT pass.
		// If it isn't a static method, add this.
		if(!fun.isStatic) {
			fun.parameters = new Parameter(fun.location, "this", new PointerType(fun.location, thisType)) ~ fun.parameters;
		}
		
		// And visit.
		pass.visit(fun.fbody);
		
		return fun;
	}
	
	Symbol visit(VariableDeclaration var) {
		var.value = pass.visit(var.value);
		
		// If the type is infered, then we use the type of the value.
		if(typeid({ return var.type; }()) is typeid(AutoType)) {
			var.type = var.value.type;
		} else {
			var.type = pass.visit(var.type);
			var.value = buildImplicitCast(var.location, var.type, var.value);
		}
		
		return var;
	}
	
	Declaration visit(FieldDeclaration f) {
		return visit(cast(VariableDeclaration) f);
	}
	
	Symbol visit(StructDefinition s) {
		auto oldThisType = thisType;
		scope(exit) thisType = oldThisType;
		
		thisType = new SymbolType(s.location, s);
		
		s.members = s.members.map!(m => visit(m)).array();
		
		return s;
	}
	
	Symbol visit(Parameter p) {
		return p;
	}
	
	Symbol visit(AliasDeclaration a) {
		return a;
	}
}

import d.ast.statement;

class StatementVisitor {
	private TypecheckPass pass;
	alias pass this;
	
	this(TypecheckPass pass) {
		this.pass = pass;
	}
	
final:
	void visit(Statement s) {
		this.dispatch(s);
	}
	
	void visit(ExpressionStatement e) {
		pass.visit(e.expression);
	}
	
	void visit(DeclarationStatement d) {
		pass.visit(d.declaration);
	}
	
	void visit(BlockStatement b) {
		foreach(s; b.statements) {
			visit(s);
		}
	}
	
	void visit(IfElseStatement ifs) {
		ifs.condition = buildExplicitCast(ifs.condition.location, new BooleanType(ifs.condition.location), pass.visit(ifs.condition));
		
		visit(ifs.then);
		visit(ifs.elseStatement);
	}
	
	void visit(WhileStatement w) {
		w.condition = buildExplicitCast(w.condition.location, new BooleanType(w.condition.location), pass.visit(w.condition));
		
		visit(w.statement);
	}
	
	void visit(DoWhileStatement w) {
		w.condition = buildExplicitCast(w.condition.location, new BooleanType(w.condition.location), pass.visit(w.condition));
		
		visit(w.statement);
	}
	
	void visit(ForStatement f) {
		visit(f.initialize);
		
		f.condition = buildExplicitCast(f.condition.location, new BooleanType(f.condition.location), pass.visit(f.condition));
		f.increment = pass.visit(f.increment);
		
		visit(f.statement);
	}
	
	void visit(ReturnStatement r) {
		r.value = buildImplicitCast(r.location, returnType, pass.visit(r.value));
	}
}

import d.ast.expression;
import d.pass.util;

class ExpressionVisitor {
	private TypecheckPass pass;
	alias pass this;
	
	this(TypecheckPass pass) {
		this.pass = pass;
	}
	
final:
	Expression visit(Expression e) out(result) {
		assert(result.type, "Type should have been set for expression " ~ typeid(result).toString() ~ " at this point.");
	} body {
		return this.dispatch(e);
	}
	
	Expression visit(BooleanLiteral bl) {
		return bl;
	}
	
	Expression visit(IntegerLiteral!true il) {
		return il;
	}
	
	Expression visit(IntegerLiteral!false il) {
		return il;
	}
	
	Expression visit(FloatLiteral fl) {
		return fl;
	}
	
	Expression visit(CharacterLiteral cl) {
		return cl;
	}
	
	Expression visit(CommaExpression ce) {
		ce.lhs = visit(ce.lhs);
		ce.rhs = visit(ce.rhs);
		
		ce.type = ce.rhs.type;
		
		return ce;
	}
	
	private auto handleBinaryExpression(string operation)(BinaryExpression!operation e) {
		e.lhs = visit(e.lhs);
		e.rhs = visit(e.rhs);
		
		import std.algorithm;
		static if(find(["&&", "||"], operation)) {
			e.type = new BooleanType(e.location);
			
			e.lhs = buildExplicitCast(e.lhs.location, e.type, e.lhs);
			e.rhs = buildExplicitCast(e.rhs.location, e.type, e.rhs);
		} else static if(find(["==", "!=", ">", ">=", "<", "<="], operation)) {
			auto type = getPromotedType(e.location, e.lhs.type, e.rhs.type);
			
			e.lhs = buildImplicitCast(e.lhs.location, type, e.lhs);
			e.rhs = buildImplicitCast(e.rhs.location, type, e.rhs);
			
			e.type = new BooleanType(e.location);
		} else static if(find(["&", "|", "^", "+", "-", "*", "/", "%"], operation)) {
			e.type = getPromotedType(e.location, e.lhs.type, e.rhs.type);
			
			e.lhs = buildImplicitCast(e.lhs.location, e.type, e.lhs);
			e.rhs = buildImplicitCast(e.rhs.location, e.type, e.rhs);
		} else static if(find(["="], operation)) {
			e.type = e.lhs.type;
			
			e.rhs = buildImplicitCast(e.rhs.location, e.type, e.rhs);
		} else static if(find([","], operation)) {
			e.type = e.rhs.type;
		}
		
		return e;
	}
	
	Expression visit(AssignExpression e) {
		return handleBinaryExpression(e);
	}
	
	Expression visit(AddExpression e) {
		return handleBinaryExpression(e);
	}
	
	Expression visit(SubExpression e) {
		return handleBinaryExpression(e);
	}
	
	Expression visit(MulExpression e) {
		return handleBinaryExpression(e);
	}
	
	Expression visit(DivExpression e) {
		return handleBinaryExpression(e);
	}
	
	Expression visit(ModExpression e) {
		return handleBinaryExpression(e);
	}
	
	Expression visit(EqualityExpression e) {
		return handleBinaryExpression(e);
	}
	
	Expression visit(NotEqualityExpression e) {
		return handleBinaryExpression(e);
	}
	
	Expression visit(GreaterExpression e) {
		return handleBinaryExpression(e);
	}
	
	Expression visit(GreaterEqualExpression e) {
		return handleBinaryExpression(e);
	}
	
	Expression visit(LessExpression e) {
		return handleBinaryExpression(e);
	}
	
	Expression visit(LessEqualExpression e) {
		return handleBinaryExpression(e);
	}
	
	Expression visit(LogicalAndExpression e) {
		return handleBinaryExpression(e);
	}
	
	Expression visit(LogicalOrExpression e) {
		return handleBinaryExpression(e);
	}
	
	private auto handleUnaryExpression(UnaryExpression)(UnaryExpression e) {
		e.expression = visit(e.expression);
		
		e.type = e.expression.type;
		
		return e;
	}
	
	Expression visit(PreIncrementExpression e) {
		return handleUnaryExpression(e);
	}
	
	Expression visit(PreDecrementExpression e) {
		return handleUnaryExpression(e);
	}
	
	Expression visit(PostIncrementExpression e) {
		return handleUnaryExpression(e);
	}
	
	Expression visit(PostDecrementExpression e) {
		return handleUnaryExpression(e);
	}
	
	Expression visit(AddressOfExpression e) {
		e = handleUnaryExpression(e);
		
		e.type = new PointerType(e.location, e.type);
		
		return e;
	}
	
	Expression visit(DereferenceExpression e) {
		e = handleUnaryExpression(e);
		
		// TODO: handle function dereference.
		if(auto pt = cast(PointerType) e.expression.type) {
			e.type = pt.type;
			
			return e;
		}
		
		assert(0, typeid({ return e.expression.type; }()).toString() ~ " is not a pointer type.");
	}
	
	Expression visit(CastExpression e) {
		return buildExplicitCast(e.location, e.type, visit(e.expression));
	}
	
	Expression visit(CallExpression c) {
		c.callee = visit(c.callee);
		
		assert(c.callee.type, "callee must have a type.");
		
		// XXX: is it the appropriate place to perform that ?
		if(auto me = cast(MethodExpression) c.callee) {
			c.callee = visit(new SymbolExpression(me.location, me.method));
			c.arguments = visit(new AddressOfExpression(me.location, visit(me.thisExpression))) ~ c.arguments;
		}
		
		// TODO: cast depending on function parameters types.
		c.arguments = c.arguments.map!(a => visit(a)).map!(a => buildImplicitCast(a.location, a.type, a)).array();
		
		c.type = c.callee.type;
		
		return c;
	}
	
	Expression visit(FieldExpression fe) {
		fe.expression = visit(fe.expression);
		
		// XXX: can't this be visited before ?
		fe.type = pass.visit(fe.field.type);
		
		return fe;
	}
	
	Expression visit(MethodExpression me) {
		me.thisExpression = visit(me.thisExpression);
		
		// XXX: can't this be visited before ?
		me.type = pass.visit(me.method.returnType);
		
		return me;
	}
	
	Expression visit(ThisExpression e) {
		e.type = thisType;
		
		return e;
	}
	
	Expression visit(SymbolExpression e) {
		// XXX: Can't that calculation be doen before ?
		e.type = pass.visit(e.symbol.type);
		
		return e;
	}
	
	Expression visit(SizeofExpression e) {
		return makeLiteral(e.location, sizeofCalculator.visit(e.argument));
	}
	
	Expression visit(DefferedExpression e) {
		return handleDefferedExpression!(delegate Expression(Expression e) {
			return visit(e);
		})(e);
	}
	
	// Will be remove by cast operation.
	Expression visit(DefaultInitializer di) {
		return di;
	}
}

import d.ast.type;

class TypeVisitor {
	private TypecheckPass pass;
	alias pass this;
	
	this(TypecheckPass pass) {
		this.pass = pass;
	}
	
final:
	Type visit(Type t) {
		return this.dispatch(t);
	}
	
	Type visit(SymbolType t) {
		return t;
	}
	
	Type visit(BooleanType t) {
		return t;
	}
	
	Type visit(IntegerType t) {
		return t;
	}
	
	Type visit(FloatType t) {
		return t;
	}
	
	Type visit(CharacterType t) {
		return t;
	}
	
	Type visit(VoidType t) {
		return t;
	}
	
	Type visit(TypeofType t) {
		return pass.visit(t.expression).type;
	}
	
	Type visit(PointerType t) {
		t.type = visit(t.type);
		
		return t;
	}
	
	Type visit(ReferenceType t) {
		t.type = visit(t.type);
		
		return t;
	}
}

class SizeofCalculator {
	private TypecheckPass pass;
	alias pass this;
	
	this(TypecheckPass pass) {
		this.pass = pass;
	}
	
final:
	uint visit(Type t) {
		return this.dispatch!(function uint(Type t) {
			assert(0, "size of type " ~ typeid(t).toString() ~ " is unknown.");
		})(t);
	}
	
	uint visit(BooleanType t) {
		return 1;
	}
	
	uint visit(IntegerType t) {
		final switch(t.type) {
			case Integer.Byte, Integer.Ubyte :
				return 1;
			
			case Integer.Short, Integer.Ushort :
				return 2;
			
			case Integer.Int, Integer.Uint :
				return 4;
			
			case Integer.Long, Integer.Ulong :
				return 8;
		}
	}
	
	uint visit(FloatType t) {
		final switch(t.type) {
			case Float.Float :
				return 4;
			
			case Float.Double :
				return 8;
			
			case Float.Real :
				return 10;
		}
	}
	
	uint visit(SymbolType t) {
		return visit(t.symbol);
	}
	
	uint visit(TypeSymbol s) {
		return this.dispatch!(function uint(TypeSymbol s) {
			assert(0, "size of type designed by " ~ typeid(s).toString() ~ " is unknown.");
		})(s);
	}
	
	uint visit(AliasDeclaration a) {
		return visit(a.type);
	}
}

import sdc.location;

private Expression buildCast(bool isExplicit = false)(Location location, Type type, Expression e) {
	// TODO: use struct to avoid memory allocation.
	final class CastFromBooleanType {
		Expression visit(Type t) {
			return this.dispatch!(function Expression(Type t) {
				auto msg = typeid(t).toString() ~ " is not supported.";
				
				import sdc.terminal;
				outputCaretDiagnostics(t.location, msg);
				
				assert(0, msg);
			})(t);
		}
		
		Expression visit(BooleanType t) {
			return e;
		}
		
		Expression visit(IntegerType t) {
			return new PadExpression(location, type, e);
		}
	}
	
	final class CastFromIntegerType {
		Integer fromType;
		
		this(Integer fromType) {
			this.fromType = fromType;
		}
		
		Expression visit(Type t) {
			return this.dispatch!(function Expression(Type t) {
				auto msg = typeid(t).toString() ~ " is not supported.";
				
				import sdc.terminal;
				outputCaretDiagnostics(t.location, msg);
				
				assert(0, msg);
			})(t);
		}
		
		static if(isExplicit) {
			Expression visit(BooleanType t) {
				Expression zero = makeLiteral(location, 0);
				auto type = getPromotedType(location, e.type, zero.type);
				
				zero = buildImplicitCast(location, type, zero);
				e = buildImplicitCast(e.location, type, e);
				
				return new NotEqualityExpression(location, e, zero);
			}
		}
		
		Expression visit(IntegerType t) {
			// TODO: remove first if. Equal type should reach here.
			if(t.type == fromType) {
				return e;
			} else if(t.type >> 1 == fromType >> 1) {
				// Same type except for signess.
				return new BitCastExpression(location, type, e);
			} else if(t.type > fromType) {
				return new PadExpression(location, type, e);
			} else static if(isExplicit) {
				return new TruncateExpression(location, type, e);
			} else {
				import std.conv;
				assert(0, "Implicit cast from " ~ to!string(fromType) ~ " to " ~ to!string(t.type) ~ " is not allowed");
			}
		}
	}
	
	final class CastFromFloatType {
		Float fromType;
		
		this(Float fromType) {
			this.fromType = fromType;
		}
		
		Expression visit(Type t) {
			return this.dispatch(t);
		}
		
		Expression visit(FloatType t) {
			import std.conv;
			assert(0, "Implicit cast from " ~ to!string(fromType) ~ " to " ~ to!string(t.type) ~ " is not allowed");
		}
	}
	
	final class CastFromCharacterType {
		Character fromType;
		
		this(Character fromType) {
			this.fromType = fromType;
		}
		
		Expression visit(Type t) {
			return this.dispatch(t);
		}
		
		Expression visit(CharacterType t) {
			import std.conv;
			assert(0, "Implicit cast from " ~ to!string(fromType) ~ " to " ~ to!string(t.type) ~ " is not allowed");
		}
	}
	
	
	final class CastFromPointerTo {
		Type fromType;
		
		this(Type fromType) {
			this.fromType = fromType;
		}
		
		Expression visit(Type t) {
			return this.dispatch!(function Expression(Type t) {
				auto msg = typeid(t).toString() ~ " is not supported.";
				
				import sdc.terminal;
				outputCaretDiagnostics(t.location, msg);
				
				assert(0, msg);
			})(t);
		}
		
		Expression visit(PointerType t) {
			static if(isExplicit) {
				return new BitCastExpression(location, type, e);
			} else if(auto toType = cast(VoidType) t.type) {
				return new BitCastExpression(location, type, e);
			} else {
				assert(0, "invalid pointer cast.");
			}
		}
	}
	
	final class Cast {
		Expression visit(Expression e) {
			return this.dispatch!(function Expression(Type t) {
				auto msg = typeid(t).toString() ~ " is not supported.";
				
				import sdc.terminal;
				outputCaretDiagnostics(t.location, msg);
				
				assert(0, msg);
			})(e.type);
		}
		
		Expression visit(BooleanType t) {
			return (new CastFromBooleanType()).visit(type);
		}
		
		Expression visit(IntegerType t) {
			return (new CastFromIntegerType(t.type)).visit(type);
		}
		
		Expression visit(FloatType t) {
			return (new CastFromFloatType(t.type)).visit(type);
		}
		
		Expression visit(CharacterType t) {
			return (new CastFromCharacterType(t.type)).visit(type);
		}
		
		Expression visit(PointerType t) {
			return (new CastFromPointerTo(t.type)).visit(type);
		}
	}
	
	// Default initializer removal.
	if(typeid(e) is typeid(DefaultInitializer)) {
		return type.initExpression(e.location);
	}
	
	if(e.type == type) return e;
	
	return (new Cast()).visit(e);
}

alias buildCast!false buildImplicitCast;
alias buildCast!true buildExplicitCast;

Type getPromotedType(Location location, Type t1, Type t2) {
	final class T2Handler {
		Integer t1type;
		
		this(Integer t1type) {
			this.t1type = t1type;
		}
		
		Type visit(Type t) {
			return this.dispatch(t);
		}
		
		Type visit(BooleanType t) {
			import std.algorithm;
			return new IntegerType(location, max(t1type, Integer.Int));
		}
		
		Type visit(IntegerType t) {
			import std.algorithm;
			// Type smaller than int are promoted to int.
			auto t2type = max(t.type, Integer.Int);
			return new IntegerType(location, max(t1type, t2type));
		}
	}
	
	final class T1Handler {
		Type visit(Type t) {
			return this.dispatch(t);
		}
		
		Type visit(BooleanType t) {
			return (new T2Handler(Integer.Int)).visit(t2);
		}
		
		Type visit(IntegerType t) {
			return (new T2Handler(t.type)).visit(t2);
		}
		
		Type visit(PointerType t) {
			// FIXME: peform the right pointer promotion.
			return t;
		}
	}
	
	return (new T1Handler()).visit(t1);
}

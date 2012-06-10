module d.ast.expression;

import d.ast.identifier;
import d.ast.statement;

import sdc.location;

class Expression : Statement, Namespace {
	this(Location location) {
		super(location);
	}
}

/**
 * Conditional expression of type ?:
 */
class ConditionalExpression : Expression {
	Expression condition;
	Expression ifTrue;
	Expression ifFalse;
	
	this(Location location, Expression condition, Expression ifTrue, Expression ifFalse) {
		super(location);
		
		this.condition = condition;
		this.ifTrue = ifTrue;
		this.ifFalse = ifFalse;
	}
}

/**
 * Binary Expression types.
 */
enum BinaryOperation {
	None,
	Comma,  // ,
	Assign,  // =
	AddAssign,  // +=
	SubAssign,  // -=
	MulAssign,  // *=
	DivAssign,  // /=
	ModAssign,  // %=
	AndAssign,  // &=
	OrAssign,   // |=
	XorAssign,  // ^=
	CatAssign,  // ~=
	ShiftLeftAssign,  // <<=
	SignedShiftRightAssign,  // >>=
	UnsignedShiftRightAssign,  // >>>=
	PowAssign,  // ^^=
	LogicalOr,  // ||
	LogicalAnd,  // &&
	BitwiseOr,  // |
	BitwiseXor,  // ^
	BitwiseAnd,  // &
	Equality,  // == 
	NotEquality,  // !=
	Is,  // is
	NotIs,  // !is
	In,  // in
	NotIn,  // !in
	Less,  // <
	LessEqual,  // <=
	Greater,  // >
	GreaterEqual,  // >=
	Unordered,  // !<>=
	UnorderedEqual,  // !<>
	LessGreater,  // <>
	LessEqualGreater,  // <>=
	UnorderedLessEqual,  // !>
	UnorderedLess, // !>=
	UnorderedGreaterEqual,  // !<
	UnorderedGreater,  // !<=
	LeftShift,  // <<
	SignedRightShift,  // >>
	UnsignedRightShift,  // >>>
	Addition,  // +
	Subtraction,  // -
	Concat,  // ~
	Division,  // /
	Multiplication,  // *
	Modulus,  // %
	Pow,  // ^^
}

class BinaryExpression : Expression {
	Expression lhs;
	Expression rhs;
	BinaryOperation operation;
	
	this(Location location, BinaryOperation operation, Expression lhs, Expression rhs) {
		super(location);
		
		this.lhs = lhs;
		this.rhs = rhs;
		this.operation = operation;
	}
}

/**
 * ,
 */
class CommaExpression : BinaryExpression {
	this(Location location, Expression lhs, Expression rhs) {
		super(location, BinaryOperation.Comma, lhs, rhs);
	}
}

/**
 * =
 */
class AssignExpression : BinaryExpression {
	this(Location location, Expression lhs, Expression rhs) {
		super(location, BinaryOperation.Assign, lhs, rhs);
	}
}

/**
 * +=, -=, *=, /=, %=, &=, |=, ^=, ~=, <<=, >>=, >>>= and ^^=
 */
class OpAssignBinaryExpression(BinaryOperation operation) if(
	operation == BinaryOperation.AddAssign
	|| operation == BinaryOperation.SubAssign
	|| operation == BinaryOperation.MulAssign
	|| operation == BinaryOperation.DivAssign
	|| operation == BinaryOperation.ModAssign
	|| operation == BinaryOperation.AndAssign
	|| operation == BinaryOperation.OrAssign
	|| operation == BinaryOperation.XorAssign
	|| operation == BinaryOperation.CatAssign
	|| operation == BinaryOperation.ShiftLeftAssign
	|| operation == BinaryOperation.SignedShiftRightAssign
	|| operation == BinaryOperation.UnsignedShiftRightAssign
	|| operation == BinaryOperation.PowAssign
) : BinaryExpression {
	this(Location location, Expression lhs, Expression rhs) {
		super(location, operation, lhs, rhs);
	}
}

/**
 * || and &&
 */
class LogicalBinaryExpression(BinaryOperation operation) if(
	operation == BinaryOperation.LogicalOr
	|| operation == BinaryOperation.LogicalAnd
) : BinaryExpression {
	this(Location location, Expression lhs, Expression rhs) {
		super(location, operation, lhs, rhs);
	}
}

/**
 * &, | and ^
 */
class BitwiseBinaryExpression(BinaryOperation operation) if(
	operation == BinaryOperation.BitwiseOr
	|| operation == BinaryOperation.BitwiseXor
	|| operation == BinaryOperation.BitwiseAnd
) : BinaryExpression {
	this(Location location, Expression lhs, Expression rhs) {
		super(location, operation, lhs, rhs);
	}
}

/**
 * == and !=
 */
class EqualityExpression(BinaryOperation operation) if(
	operation == BinaryOperation.Equality
	|| operation == BinaryOperation.NotEquality
) : BinaryExpression {
	this(Location location, Expression lhs, Expression rhs) {
		super(location, operation, lhs, rhs);
	}
}

/**
 * is and !is
 */
class IsExpression(BinaryOperation operation) if(
	operation == BinaryOperation.In
	|| operation == BinaryOperation.NotIn
) : BinaryExpression {
	this(Location location, Expression lhs, Expression rhs) {
		super(location, operation, lhs, rhs);
	}
}

/**
 * in and !in
 */
class IsExpression(BinaryOperation operation) if(
	operation == BinaryOperation.Is
	|| operation == BinaryOperation.NotIs
) : BinaryExpression {
	this(Location location, Expression lhs, Expression rhs) {
		super(location, operation, lhs, rhs);
	}
}

/**
 * <, <=, >, >=, <>, <>=, !<, !<=, !>, !>=, !<> and !<>=
 */
class ComparaisonExpression(BinaryOperation operation) if(
	operation == BinaryOperation.Less
	|| operation == BinaryOperation.LessEqual
	|| operation == BinaryOperation.Greater
	|| operation == BinaryOperation.GreaterEqual
	|| operation == BinaryOperation.Unordered
	|| operation == BinaryOperation.UnorderedEqual
	|| operation == BinaryOperation.LessGreater
	|| operation == BinaryOperation.LessEqualGreater
	|| operation == BinaryOperation.UnorderedLessEqual
	|| operation == BinaryOperation.UnorderedLess
	|| operation == BinaryOperation.UnorderedGreaterEqual
	|| operation == BinaryOperation.UnorderedGreater
) : BinaryExpression {
	this(Location location, Expression lhs, Expression rhs) {
		super(location, operation, lhs, rhs);
	}
}

/**
 * <<, >> and >>>
 */
class ShiftExpression(BinaryOperation operation) if(
	operation == BinaryOperation.LeftShift
	|| operation == BinaryOperation.SignedRightShift
	|| operation == BinaryOperation.UnsignedRightShift
) : BinaryExpression {
	this(Location location, Expression lhs, Expression rhs) {
		super(location, operation, lhs, rhs);
	}
}

/**
 * Binary +, -, ~, *, /, %, and ^^
 */
class OperationBinaryExpression(BinaryOperation operation) if(
	operation == BinaryOperation.Addition
	|| operation == BinaryOperation.Subtraction
	|| operation == BinaryOperation.Concat
	|| operation == BinaryOperation.Multiplication
	|| operation == BinaryOperation.Division
	|| operation == BinaryOperation.Modulus
	|| operation == BinaryOperation.Pow
) : BinaryExpression {
	this(Location location, Expression lhs, Expression rhs) {
		super(location, operation, lhs, rhs);
	}
}

alias OperationBinaryExpression!(BinaryOperation.Addition) AdditionExpression;
alias OperationBinaryExpression!(BinaryOperation.Subtraction) SubstractionExpression;
alias OperationBinaryExpression!(BinaryOperation.Concat) ConcatExpression;

/**
 * Unary Prefix Expression types.
 */
enum UnaryPrefix {
	None,
	AddressOf,  // &
	PrefixInc,  // ++
	PrefixDec,  // --
	Dereference,  // *
	UnaryPlus,  // +
	UnaryMinus,  // -
	LogicalNot,  // !
	BitwiseNot,  // ~
	Cast,  // cast (type) unaryExpr
	New,
}


class PrefixUnaryExpression : Expression {
	Expression expression;
	UnaryPrefix operation;
	
	this(Location location, UnaryPrefix operation, Expression expression) {
		super(location);
		
		this.expression = expression;
		this.operation = operation;
	}
}

/**
 * Unary &
 */
class AddressOfExpression : PrefixUnaryExpression {
	this(Location location, Expression expression) {
		super(location, UnaryPrefix.AddressOf, expression);
	}
}

/**
 * Prefixed ++ and --
 */
class OpAssignUnaryExpression(UnaryPrefix operation) if(
	operation == UnaryPrefix.PrefixInc
	|| operation == UnaryPrefix.PrefixDec
) : PrefixUnaryExpression {
	this(Location location, Expression expression) {
		super(location, operation, expression);
	}
}

/**
 * Unary *
 */
class DereferenceExpression : PrefixUnaryExpression {
	this(Location location, Expression expression) {
		super(location, UnaryPrefix.Dereference, expression);
	}
}

/**
 * Unary + and -
 */
class OperationUnaryExpression(UnaryPrefix operation) if(
	operation == UnaryPrefix.UnaryPlus
	|| operation == UnaryPrefix.UnaryMinus
) : PrefixUnaryExpression {
	this(Location location, Expression expression) {
		super(location, operation, expression);
	}
}

/**
 * !
 */
class NotExpression : PrefixUnaryExpression {
	this(Location location, Expression expression) {
		super(location, UnaryPrefix.LogicalNot, expression);
	}
}

/**
 * Unary ~
 */
class CompelementExpression : PrefixUnaryExpression {
	this(Location location, Expression expression) {
		super(location, UnaryPrefix.BitwiseNot, expression);
	}
}

/**
 * Unary Postfix Expression types.
 */
enum PostfixType {
	Primary,
	Dot,  // . QualifiedName  // XXX: specs say a new expression can go here: DMD disagrees.
	PostfixInc,  // ++
	PostfixDec,  // --
	Parens,  // ( ArgumentList* )
	Index,  // [ ArgumentList ]
	Slice,  // [ (ConditionalExpression .. ConditionalExpression)* ]
}

class PostfixUnaryExpression : Expression {
	Expression expression;
	PostfixType operation;
	
	this(Location location, PostfixType operation, Expression expression) {
		super(location);
		
		this.expression = expression;
		this.operation = operation;
	}
}

/**
 * Postfixed ++ and --
 */
class OpAssignUnaryExpression(PostfixType operation) if(
	operation == PostfixType.PostfixInc
	|| operation == PostfixType.PostfixDec
) : PostfixUnaryExpression {
	this(Location location, Expression expression) {
		super(location, operation, expression);
	}
}

/**
 * Function call
 */
class CallExpression : PostfixUnaryExpression {
	Expression[] parameters;
	
	this(Location location, Expression expression, Expression[] parameters) {
		super(location, PostfixType.Parens, expression);
		
		this.parameters = parameters;
	}
}

enum PrimaryType {
	Identifier,
	This,
	Super,
	Null,
	True,
	False,
	Dollar,
	__File__,
	__Line__,
	IntegerLiteral,
	FloatLiteral,
	CharacterLiteral,
	StringLiteral,
	ArrayLiteral,
	AssocArrayLiteral,
	FunctionLiteral,
	AssertExpression,
	MixinExpression,
	ImportExpression,
	BasicTypeDotIdentifier,
	ComplexTypeDotIdentifier,
	Typeof,
	TypeidExpression,
	IsExpression,
	ParenExpression,
	TraitsExpression,
}

/**
 * Primary Expressions
 */
class PrimaryExpression : Expression {
	private PrimaryType type;
	
	this(Location location, PrimaryType type) {
		super(location);
		
		this.type = type;
	}
}

/**
 * Identifier expression
 */
class IdentifierExpression : PrimaryExpression {
	Identifier identifier;
	
	this(Location location, Identifier identifier) {
		super(location, PrimaryType.Identifier);
		
		this.identifier = identifier;
	}
}

/**
 * This
 */
class ThisExpression : PrimaryExpression {
	this(Location location) {
		super(location, PrimaryType.This);
	}
}

/**
 * Super
 */
class SuperExpression : PrimaryExpression {
	this(Location location) {
		super(location, PrimaryType.Super);
	}
}

/**
 * Integer literals
 */
import std.traits;
class IntegerLiteral(T) if(isIntegral!T) : PrimaryExpression {
	T value;
	
	this(Location location, T value) {
		super(location, PrimaryType.IntegerLiteral);
		
		this.value = value;
	}
}

/**
 * String literals
 */
class StringLiteral : PrimaryExpression {
	string value;
	
	this(Location location, string value) {
		super(location, PrimaryType.StringLiteral);
		
		this.value = value;
	}
}

/**
 * Boolean literals
 */
class BooleanLiteral(bool value) : PrimaryExpression {
	this(Location location) {
		static if(value) {
			super(location, PrimaryType.True);
		} else {
			super(location, PrimaryType.False);
		}
	}
}

/**
 * Null literals
 */
class NullLiteral : PrimaryExpression {
	this(Location location) {
		super(location, PrimaryType.Null);
	}
}

/**
 * __FILE__ literals
 */
class __File__Literal : PrimaryExpression {
	this(Location location) {
		super(location, PrimaryType.__File__);
	}
}

/**
 * __LINE__ literals
 */
class __Line__Literal : PrimaryExpression {
	this(Location location) {
		super(location, PrimaryType.__Line__);
	}
}


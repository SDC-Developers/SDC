module d.ast.dtemplate;

import d.ast.declaration;
import d.ast.type;

import sdc.location;

/**
 * Template declaration
 */
class TemplateDeclaration : Declaration {
	string name;
	TemplateParameter[] parameters;
	Declaration[] declarations;
	
	this(Location location, string name, TemplateParameter[] parameters, Declaration[] declarations) {
		super(location, DeclarationType.Template);
		
		this.name = name;
		this.parameters = parameters;
		this.declarations = declarations;
	}
}

enum TemplateParameterType {
	Type,
	Value,
	Alias,
	Tuple,
	This,
}

/**
 * Super class for all templates parameters
 */
class TemplateParameter : Declaration {
	TemplateParameterType parameterType;
	
	this(Location location, TemplateParameterType parameterType) {
		super(location, DeclarationType.TemplateParameter);
		
		this.parameterType = parameterType;
	}
}

/**
 * Types templates parameters
 */
class TypeTemplateParameter : TemplateParameter {
	string name;
	
	this(Location location, string name) {
		super(location, TemplateParameterType.Type);
		
		this.name = name;
	}
}

/**
 * This templates parameters
 */
class ThisTemplateParameter : TemplateParameter {
	string name;
	
	this(Location location, string name) {
		super(location, TemplateParameterType.This);
		
		this.name = name;
	}
}

/**
 * Tuple templates parameters
 */
class TupleTemplateParameter : TemplateParameter {
	string name;
	
	this(Location location, string name) {
		super(location, TemplateParameterType.This);
		
		this.name = name;
	}
}

/**
 * Value template parameters
 */
class ValueTemplateParameter : TemplateParameter {
	string name;
	Type type;
	
	this(Location location, string name, Type type) {
		super(location, TemplateParameterType.This);
		
		this.name = name;
		this.type = type;
	}
}

/**
 * Alias template parameter
 */
class AliasTemplateParameter : TemplateParameter {
	string name;
	
	this(Location location, string name) {
		super(location, TemplateParameterType.Alias);
		
		this.name = name;
	}
}

/**
 * Typed alias template parameter
 */
class TypedAliasTemplateParameter : AliasTemplateParameter {
	Type type;
	
	this(Location location, string name, Type type) {
		super(location, name);
		
		this.type = type;
	}
}


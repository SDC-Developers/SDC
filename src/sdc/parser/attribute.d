/**
 * Copyright 2010-2011 Bernard Helyer.
 * This file is part of SDC. SDC is licensed under the GPL.
 * See LICENCE or sdc.d for more details.
 */
module sdc.parser.attribute;

import std.string;

import sdc.util;
import sdc.global;
import sdc.compilererror;
import sdc.tokenstream;
import sdc.parser.base;
import sdc.parser.expression;
import sdc.ast.attribute;
import sdc.ast.declaration;


AttributeSpecifier parseAttributeSpecifier(TokenStream tstream)
{
    auto attributeSpecifier = new AttributeSpecifier();
    attributeSpecifier.location = tstream.peek.location;

    auto name = tstream.peek.value;
    verbosePrint("Parsing " ~ name ~ " attribute specifier.", VerbosePrintColour.Green);
    verboseIndent++;
    attributeSpecifier.attribute = parseAttribute(tstream);
    attributeSpecifier.declarationBlock = parseDeclarationBlock(tstream);
    verboseIndent--;
    verbosePrint("Done parsing " ~ name ~ " attribute specifier.", VerbosePrintColour.Green);
    return attributeSpecifier;
}

Attribute parseFunctionAttribute(TokenStream tstream)
{
    auto attribute = parseAttribute(tstream);
    if (FUNCTION_ATTRIBUTES.contains(attribute.type) || MEMBER_FUNCTION_ATTRIBUTES.contains(attribute.type)) {
        return attribute;
    }
    throw new CompilerError(attribute.location, "expected function attribute.");
}

Attribute parseAttribute(TokenStream tstream)
{
    auto attribute = new Attribute();
    attribute.location = tstream.peek.location;
    
    Attribute parseExtern()
    {
        match(tstream, TokenType.Extern);
        if (tstream.peek.type != TokenType.OpenParen) {
            throw new CompilerPanic(tstream.peek.location, "ICE: only linkage style extern supported.");
        }
        match(tstream, TokenType.OpenParen);
        switch (tstream.peek.value) {
        case "C":
            if (tstream.lookahead(1).type == TokenType.DoublePlus) {
                match(tstream, TokenType.Identifier);
                attribute.type = AttributeType.ExternCPlusPlus;
            } else {
                attribute.type = AttributeType.ExternC;
            }
            break;
        case "D":
            attribute.type = AttributeType.ExternD;
            break;
        case "Windows":
            attribute.type = AttributeType.ExternWindows;
            break;
        case "Pascal":
            attribute.type = AttributeType.ExternPascal;
            break;
        case "System":;
            attribute.type = AttributeType.ExternSystem;
            break;
        default:
            throw new CompilerError(
                tstream.peek.location, 
                "unsupported extern linkage. Supported linkages are C, C++, D, Windows, Pascal, and System."
            );
        }
        tstream.getToken();
        match(tstream, TokenType.CloseParen);
        
        return attribute;
    }
    
    switch (tstream.peek.type) {
    case TokenType.Deprecated: case TokenType.Private:
    case TokenType.Package: case TokenType.Protected:
    case TokenType.Public: case TokenType.Export:
    case TokenType.Static: case TokenType.Final:
    case TokenType.Override: case TokenType.Abstract:
    case TokenType.Const: case TokenType.Auto:
    case TokenType.Scope: case TokenType.__Gshared:
    case TokenType.Shared: case TokenType.Immutable:
    case TokenType.Inout: case TokenType.Pure: 
    case TokenType.Nothrow:
        // Simple keyword attribute.
        attribute.type = cast(AttributeType) tstream.peek.type;
        tstream.getToken();
        break;
    case TokenType.At:
        match(tstream, TokenType.At);
        if (tstream.peek.type != TokenType.Identifier) {
            throw new CompilerError(tstream.peek.location, format("expected identifier, not %s.", tokenToString[tstream.peek.type]));
        }
        switch (tstream.peek.value) {
        case "safe": attribute.type = AttributeType.atSafe; break;
        case "trusted": attribute.type = AttributeType.atTrusted; break;
        case "system": attribute.type = AttributeType.atSystem; break;
        case "disable": attribute.type = AttributeType.atDisable; break;
        case "property": attribute.type = AttributeType.atProperty; break;
        default:
            throw new CompilerError(tstream.peek.location, format("expected attribute, not @%s.", tstream.peek.value));
        }
        match(tstream, TokenType.Identifier);
        break;
    case TokenType.Align:
        attribute.type = AttributeType.Align;
        attribute.node = parseAlignAttribute(tstream);
        break;
    case TokenType.Pragma:
        break;
    case TokenType.Extern:
        return parseExtern();
    default:
        throw new CompilerError(
            tstream.peek.location, 
            format("bad attribute '%s'.", tokenToString[tstream.peek.type])
        );
    }
    
    return attribute;
}


bool startsLikeAttribute(TokenStream tstream)
{
    if (contains(PAREN_TYPES, tstream.peek.type) && tstream.lookahead(1).type == TokenType.OpenParen) {
        return false;
    }
    if (tstream.peek.type == TokenType.Static) { // TODO: I have a feeling this doesn't belong here...
        if (tstream.lookahead(1).type == TokenType.Assert ||
            tstream.lookahead(1).type == TokenType.Import ||
            tstream.lookahead(1).type == TokenType.If) {
            return false;
        }
    }
    return contains(ATTRIBUTE_KEYWORDS, tstream.peek.type) || tstream.peek.type == TokenType.At;
}


AlignAttribute parseAlignAttribute(TokenStream tstream)
{
    auto alignAttribute = new AlignAttribute();
    alignAttribute.location = tstream.peek.location;
    match(tstream, TokenType.Align);
    if (tstream.peek.type == TokenType.OpenParen) {
        match(tstream, TokenType.OpenParen);
        alignAttribute.integerLiteral = parseIntegerLiteral(tstream);
        match(tstream, TokenType.CloseParen);
    }
    return alignAttribute;
}


PragmaAttribute parsePragmaAttribute(TokenStream tstream)
{
    auto pragmaAttribute = new PragmaAttribute();
    pragmaAttribute.location = tstream.peek.location;
    match(tstream, TokenType.Pragma);
    match(tstream, TokenType.OpenParen);
    pragmaAttribute.identifier = parseIdentifier(tstream);
    if (tstream.peek.type == TokenType.Comma) {
        match(tstream, TokenType.Comma);
        pragmaAttribute.argumentList = parseArgumentList(tstream);
    }
    match(tstream, TokenType.CloseParen);
    return pragmaAttribute;
}

DeclarationBlock parseDeclarationBlock(TokenStream tstream, bool attributeBlock = false)
{
    auto declarationBlock = new DeclarationBlock();
    declarationBlock.location = tstream.peek.location;
    
    if (tstream.peek.type == TokenType.OpenBrace) {
        match(tstream, TokenType.OpenBrace);
        while (tstream.peek.type != TokenType.CloseBrace) {
            if (attributeBlock) declarationBlock.declarationDefinitions ~= parseAttributeBlock(tstream);
            else declarationBlock.declarationDefinitions ~= parseDeclarationDefinition(tstream);
        }
        match(tstream, TokenType.CloseBrace);
    } else if (tstream.peek.type == TokenType.Colon) {
        match(tstream, TokenType.Colon);
        while (tstream.peek.type != TokenType.End && tstream.peek.type != TokenType.CloseBrace) {
            if (attributeBlock) declarationBlock.declarationDefinitions ~= parseAttributeBlock(tstream); 
            else declarationBlock.declarationDefinitions ~= parseDeclarationDefinition(tstream);
        }
    } else {
        if (attributeBlock) declarationBlock.declarationDefinitions ~= parseAttributeBlock(tstream);
        else declarationBlock.declarationDefinitions ~= parseDeclarationDefinition(tstream);
    }
    
    return declarationBlock;
}

import SwiftCompilerPlugin
import SwiftSyntax
import SwiftSyntaxBuilder
import SwiftSyntaxMacros
import SwiftDiagnostics

/// Implementation of the `stringify` macro, which takes an expression
/// of any type and produces a tuple containing the value of that expression
/// and the source code that produced the value. For example
///
///     #stringify(x + y)
///
///  will expand to
///
///     (x + y, "x + y")
public struct StringifyMacro: ExpressionMacro {
    public static func expansion(
        of node: some FreestandingMacroExpansionSyntax,
        in context: some MacroExpansionContext
    ) -> ExprSyntax {
        guard let argument = node.arguments.first?.expression else {
            fatalError("compiler bug: the macro does not have any arguments")
        }

        return "(\(argument), \(literal: argument.description))"
    }
}

public struct DictionaryMakerMacro: ExpressionMacro {
    public static func expansion(
        of node: some FreestandingMacroExpansionSyntax,
        in context: some MacroExpansionContext
    ) throws -> ExprSyntax {
        guard !node.arguments.isEmpty else {
            let diagnose = Diagnostic(node: node._syntaxNode, message: "Empty input" as! DiagnosticMessage)
            context.diagnose(diagnose)
            throw DiagnosticsError(diagnostics: [diagnose])
        }
        
        var cachedKeys = Set<String>()
        var elements = [DictionaryElementSyntax]()
        
        for (i, arg) in node.arguments.enumerated() {
            guard arg.expression.is(DeclReferenceExprSyntax.self) else {
                let diagnose = Diagnostic(node: arg._syntaxNode, message: "Incorrect input" as! DiagnosticMessage)
                context.diagnose(diagnose)
                throw DiagnosticsError(diagnostics: [diagnose])
            }
            let syntax = arg.expression.cast(DeclReferenceExprSyntax.self)
            let key = syntax.baseName.text
            
            guard !cachedKeys.contains(key) else {
                let diagnose = Diagnostic(node: arg._syntaxNode, message: "Duplicated key" as! DiagnosticMessage)
                context.diagnose(diagnose)
                throw DiagnosticsError(diagnostics: [diagnose])
            }
            
            let trailingComma = i == node.arguments.count - 1 ? nil : TokenSyntax.commaToken()
            elements.append(DictionaryElementSyntax(key: StringLiteralExprSyntax(content: key), value: syntax, trailingComma: trailingComma))
            cachedKeys.insert(key)
        }
        
        let dictionaryLiteral = DictionaryExprSyntax(content: .elements(DictionaryElementListSyntax(elements)))
        return ExprSyntax(dictionaryLiteral)
    }
}

@main
struct DictionaryMakerPlugin: CompilerPlugin {
    let providingMacros: [Macro.Type] = [
        DictionaryMakerMacro.self,
    ]
}

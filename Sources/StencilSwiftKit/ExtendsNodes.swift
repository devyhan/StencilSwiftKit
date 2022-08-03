//
//  File.swift
//  
//
//  Created by 조요한 on 2022/10/21.
//

import Foundation

class ExtendsNode: NodeType {
  let templateName: Variable
  let blocks: [String: BlockNode]
  let token: Token?

  class func parse(_ parser: TokenParser, token: Token) throws -> NodeType {
    let bits = token.components

    guard bits.count == 2 else {
      throw TemplateSyntaxError("'extends' takes one argument, the template file to be extended")
    }

    let parsedNodes = try parser.parse()
    guard (parsedNodes.any { $0 is ExtendsNode }) == nil else {
      throw TemplateSyntaxError("'extends' cannot appear more than once in the same template")
    }

    let blockNodes = parsedNodes.compactMap { $0 as? BlockNode }
    let nodes = blockNodes.reduce(into: [String: BlockNode]()) { accumulator, node in
      accumulator[node.name] = node
    }

    return ExtendsNode(templateName: Variable(bits[1]), blocks: nodes, token: token)
  }

  init(templateName: Variable, blocks: [String: BlockNode], token: Token) {
    self.templateName = templateName
    self.blocks = blocks
    self.token = token
  }

  func render(_ context: Context) throws -> String {
    guard let templateName = try self.templateName.resolve(context) as? String else {
      throw TemplateSyntaxError("'\(self.templateName)' could not be resolved as a string")
    }

    let baseTemplate = try context.environment.loadTemplate(name: templateName)

    let blockContext: BlockContext
    if let currentBlockContext = context[BlockContext.contextKey] as? BlockContext {
      blockContext = currentBlockContext
      for (name, block) in blocks {
        blockContext.push(block, forKey: name)
      }
    } else {
      blockContext = BlockContext(blocks: blocks)
    }

    do {
      // pushes base template and renders it's content
      // block_context contains all blocks from child templates
      return try context.push(dictionary: [BlockContext.contextKey: blockContext]) {
        try baseTemplate.render(context)
      }
    } catch {
      // if error template is already set (see catch in BlockNode)
      // and it happend in the same template as current template
      // there is no need to wrap it in another error
      if let error = error as? TemplateSyntaxError, error.templateName != token?.sourceMap.filename {
        throw TemplateSyntaxError(reason: error.reason, stackTrace: error.allTokens)
      } else {
        throw error
      }
    }
  }
}

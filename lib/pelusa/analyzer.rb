module Pelusa
  class Analyzer
    # Public: Initializes an Analyzer.
    #
    # ast      - The abstract syntax tree to analyze.
    # reporter - The class that will be used to create the report.
    # filename - The name of the file that we're analyzing.
    def initialize(lints, reporter, filename)
      @lints    = lints
      @ast      = parser.parse_file(filename)
      @reporter = reporter.new(filename)
    end

    # Public: Makes a report out of several classes contained in the AST.
    #
    # ast - The abstract syntax tree to analyze.
    #
    # Returns a Report of all the classes.
    def analyze
      reports = AnalyzedClass.classes_from_ast(@ast).map do |analyzed_class|
        class_analyzer = ClassAnalyzer.new(analyzed_class.class_node)
        class_name     = class_analyzer.class_name
        type           = class_analyzer.type
        analysis       = class_analyzer.analyze(@lints)

        Report.new(class_name, type, analysis)
      end
      @reporter.reports = reports
      @reporter
    end

    #######
    private
    #######

    # Internal: Elements that should be ignored when detecting whether a class
    # has content (as opposed to simply namespacing other classes). When
    # publishing a report, we want to include the most specific class -- e.g.
    # if we have:
    #   class Foo
    #     module Bar
    #       def baz
    #       end
    #     end
    #   end
    # Then we should display the analysis of baz for Bar, not for both Foo and Bar.
    NEUTRAL_ELEMENTS = [
      Rubinius::AST::Class,
      Rubinius::AST::ClassScope,
      Rubinius::AST::ClassName,
      Rubinius::AST::Module,
      Rubinius::AST::ModuleScope,
      Rubinius::AST::ModuleName,
      Rubinius::AST::Block,
      Rubinius::AST::DefineSingleton,
      Rubinius::AST::DefineSingletonScope,
      Rubinius::AST::NilLiteral
    ]

    class AnalyzedClass
      attr_reader :class_node
      def initialize(node)
        @class_node = node
      end

      # Public: Get all the children classes
      def components
        [self] + analyzed_children
      end

      def empty?
        !@interesting
      end

      def self.container?(node)
        node.is_a?(Rubinius::AST::Class) ||
          node.is_a?(Rubinius::AST::Module)
      end

      # Internal: Extracts the classes out of the AST and returns their nodes.
      #
      # ast - The abstract syntax tree to extract the classes from.
      #
      # Returns an Array of AnalyzedClass instances.
      def self.classes_from_ast(ast, exclude_empty = true)
        classes = []
        if container?(ast)
          classes += new(ast).components
        else
          # parse through whatever else we find
          ast.children do |node|
            classes += new(node).components if container?(node)
          end
        end
        # if exclude_empty, exclude deleted classes
        classes.reject {|klass| exclude_empty && klass.empty?}
      end

      private

      # Internal: Walk the AST for this class to analyze and collect all the
      # classes and modules contained inside this class (descending recursively
      # into any subclasses and modules).  While we're at it, we also see if
      # the class is interesting (e.g. contains more than other classes and
      # modules).
      #
      # Returns an array of AnalyzedClasses for all the classes and modules
      # inside this class and any subclasses/submodules.
      def analyzed_children
        classes = []
        @class_node.walk do |truth, node|
          # For any children here, gather them up
          if AnalyzedClass.container?(node)
            classes += AnalyzedClass.new(node).components
            # don't continue walking this node
            false
          else
            # see if we have an interesting component
            @interesting = true unless NEUTRAL_ELEMENTS.include?(node.class)
            # continue walking
            true
          end
        end
        classes
      end
    end

    # Internal: Returns the Melbourne 1.9 parser.
    #
    # Returns a Rubinius::Melbourne parser.
    def parser
      Rubinius::Melbourne19
    end
  end
end

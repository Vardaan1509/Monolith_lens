# frozen_string_literal: true

RSpec.describe MonolithLens::Static::SourceAnalyzer do
  def analyze(source, source_file: "test.rb")
    described_class.analyze(source, source_file: source_file).edges
  end

  it "records a class inheritance edge with a fully-qualified source" do
    source = <<~RUBY
      module Billing
        class InvoiceProcessor < BaseProcessor
        end
      end
    RUBY

    edges = analyze(source, source_file: "app/billing/invoice_processor.rb")

    expect(edges.length).to eq(1)
    edge = edges.first
    expect(edge.source).to eq("Billing::InvoiceProcessor")
    expect(edge.target).to eq("BaseProcessor")
    expect(edge.dependency_type).to eq(:inheritance)
  end

  it "captures static evidence with the correct line and rule" do
    source = <<~RUBY
      class Report < BaseReport
      end
    RUBY

    evidence = analyze(source).first.evidence.first

    expect(evidence.kind).to eq(:static)
    expect(evidence.rule).to eq("class_inheritance")
    expect(evidence.line).to eq(1)
  end

  it "resolves a namespaced superclass to its full name" do
    source = <<~RUBY
      class User < ActiveRecord::Base
      end
    RUBY

    expect(analyze(source).first.target).to eq("ActiveRecord::Base")
  end

  it "returns no edges for a class without a superclass" do
    expect(analyze("class Plain; end")).to be_empty
  end

  it "returns no edges (instead of raising) when the source has a syntax error" do
    expect(analyze("class Broken")).to eq([])
  end

  it "records include/prepend/extend as mixin edges of the right type" do
    source = <<~RUBY
      class InvoiceProcessor
        include Auditable
        prepend Loggable
        extend Configurable
      end
    RUBY

    types = analyze(source).to_h { |edge| [edge.target, edge.dependency_type] }

    expect(types).to eq(
      "Auditable" => :include,
      "Loggable" => :prepend,
      "Configurable" => :extend
    )
  end

  it "records each module listed in a single include" do
    source = <<~RUBY
      class Report
        include Printable, Exportable
      end
    RUBY

    expect(analyze(source).map(&:target)).to contain_exactly("Printable", "Exportable")
  end

  it "resolves a namespaced mixin and tags its evidence rule" do
    source = <<~RUBY
      class Report
        include Concerns::Trackable
      end
    RUBY

    edge = analyze(source).first
    expect(edge.target).to eq("Concerns::Trackable")
    expect(edge.evidence.first.rule).to eq("module_include")
  end

  it "records a qualified constant used as a call receiver (stronger rule)" do
    source = <<~RUBY
      module Billing
        class InvoiceProcessor
          def call
            Accounts::User.find(1)
          end
        end
      end
    RUBY

    edge = analyze(source).first
    expect(edge.source).to eq("Billing::InvoiceProcessor")
    expect(edge.target).to eq("Accounts::User")
    expect(edge.dependency_type).to eq(:constant_reference)
    expect(edge.evidence.first.rule).to eq("constant_reference_call")
  end

  it "records a qualified constant used as a plain value (weaker rule)" do
    source = <<~RUBY
      class Report
        def build
          klass = Accounts::User
          klass
        end
      end
    RUBY

    edge = analyze(source).first
    expect(edge.target).to eq("Accounts::User")
    expect(edge.evidence.first.rule).to eq("constant_reference_value")
  end

  it "does not record bare (unqualified) constant references" do
    source = <<~RUBY
      class Report
        def build
          User.find(1)
          value = MAX_SIZE
          value
        end
      end
    RUBY

    expect(analyze(source)).to be_empty
  end

  it "records a qualified constant reference exactly once (no double counting)" do
    source = <<~RUBY
      class Report
        def build
          Accounts::User.find(1)
        end
      end
    RUBY

    expect(analyze(source).length).to eq(1)
  end

  it "records the full nested path, not its sub-paths" do
    source = <<~RUBY
      class Report
        def build
          Accounts::Admin::User.find(1)
        end
      end
    RUBY

    expect(analyze(source).map(&:target)).to eq(["Accounts::Admin::User"])
  end

  it "does not double-record a namespaced superclass as a reference" do
    source = <<~RUBY
      class User < ActiveRecord::Base
      end
    RUBY

    edges = analyze(source)
    expect(edges.length).to eq(1)
    expect(edges.first.dependency_type).to eq(:inheritance)
  end

  it "records references from multiple qualified constants in a method" do
    source = <<~RUBY
      module Billing
        class InvoiceProcessor
          def call
            user = Accounts::User.find(1)
            Notifications::Mailer.deliver(user)
          end
        end
      end
    RUBY

    targets = analyze(source).map(&:target)
    expect(targets).to contain_exactly("Accounts::User", "Notifications::Mailer")
  end

  it "records the constants (classes and modules) defined in the source" do
    source = <<~RUBY
      module Billing
        class Invoice
        end
      end
    RUBY

    definitions = described_class.analyze(source, source_file: "billing/invoice.rb").definitions

    expect(definitions.map(&:constant)).to contain_exactly("Billing", "Billing::Invoice")
  end
end

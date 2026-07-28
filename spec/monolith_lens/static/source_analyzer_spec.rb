# frozen_string_literal: true

RSpec.describe MonolithLens::Static::SourceAnalyzer do
  def analyze(source, source_file: "test.rb")
    described_class.analyze(source, source_file: source_file)
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
end

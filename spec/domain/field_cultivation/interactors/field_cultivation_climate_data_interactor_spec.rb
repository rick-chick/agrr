require "rails_helper"

RSpec.describe Domain::FieldCultivation::Interactors::FieldCultivationClimateDataInteractor do
  describe "#call" do
    let(:field_cultivation_id) { 42 }
    let(:output_port) do
      instance_double(Domain::FieldCultivation::Ports::FieldCultivationClimateDataOutputPort)
    end
    let(:gateway) do
      instance_double(Domain::FieldCultivation::Gateways::FieldCultivationGateway)
    end
    let(:logger) do
      instance_double(ActiveSupport::Logger).tap do |logger_double|
        allow(logger_double).to receive(:warn)
        allow(logger_double).to receive(:error)
      end
    end
    let(:interactor) do
      described_class.new(output_port: output_port, gateway: gateway, logger: logger)
    end
    let(:input_dto) do
      Domain::FieldCultivation::Dtos::FieldCultivationClimateDataInputDto.new(
        field_cultivation_id: field_cultivation_id
      )
    end

    context "when gateway returns data" do
      let(:success_dto) do
        Domain::FieldCultivation::Dtos::FieldCultivationClimateDataSuccessDto.new(
          field_cultivation: { id: field_cultivation_id, field_name: "north", crop_name: "tomato" },
          farm: { id: 1, name: "Yokohama Farm", latitude: 35.4, longitude: 139.6 },
          crop_requirements: { base_temperature: 10.0 },
          weather_data: [],
          gdd_data: [],
          stages: [],
          progress_result: {},
          debug_info: {}
        )
      end

      it "delivers the climate information" do
        expect(gateway).to receive(:fetch_field_cultivation_climate_data)
          .with(field_cultivation_id: field_cultivation_id)
          .and_return(success_dto)
        expect(output_port).to receive(:present).with(success_dto)

        interactor.call(input_dto)
      end
    end

    context "when gateway raises an error" do
      let(:error) { StandardError.new("progress failure") }

      it "routes the failure through the output port" do
        expect(gateway).to receive(:fetch_field_cultivation_climate_data).and_raise(error)
        expect(output_port).to receive(:on_error).with(have_attributes(message: error.message))

        interactor.call(input_dto)
      end
    end
  end
end

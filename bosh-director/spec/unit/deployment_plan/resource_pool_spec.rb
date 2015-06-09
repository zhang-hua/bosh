require 'spec_helper'

module Bosh::Director::DeploymentPlan
  describe ResourcePool do
    subject(:resource_pool) { ResourcePool.new(plan, valid_spec, logger) }
    let(:max_size) { 2 }

    let(:valid_spec) do
      {
        'name' => 'small',
        'size' => max_size,
        'network' => 'test',
        'stemcell' => {
          'name' => 'stemcell-name',
          'version' => '0.5.2'
        },
        'cloud_properties' => { 'foo' => 'bar' },
        'env' => { 'key' => 'value' },
      }
    end

    let(:network) { instance_double('Bosh::Director::DeploymentPlan::Network') }
    let(:plan) { instance_double('Bosh::Director::DeploymentPlan::Planner') }

    before { allow(plan).to receive(:network).with('test').and_return(network) }

    describe '#vms' do
      before do
        2.times { resource_pool.allocate_vm }
      end

      it 'returns a list of the allocated vms' do
        expect(resource_pool.vms).to contain_exactly(
          resource_pool.allocated_vms[0],
          resource_pool.allocated_vms[1],
        )
      end
    end

    describe 'creating' do
      it 'parses name, size, stemcell spec, cloud properties, env' do
        expect(resource_pool.name).to eq('small')
        expect(resource_pool.stemcell).to be_kind_of(Stemcell)
        expect(resource_pool.stemcell.name).to eq('stemcell-name')
        expect(resource_pool.stemcell.version).to eq('0.5.2')
        expect(resource_pool.network).to eq(network)
        expect(resource_pool.cloud_properties).to eq({ 'foo' => 'bar' })
        expect(resource_pool.env).to eq({ 'key' => 'value' })
      end

      context 'when name is missing' do
        before { valid_spec.delete('name') }

        it 'raises an error' do
          expect { ResourcePool.new(plan, valid_spec, logger) }.to raise_error(BD::ValidationMissingField)
        end
      end

      context 'when cloud_properties is missing' do
        before { valid_spec.delete('cloud_properties') }

        it 'defaults to empty hash' do
          expect(resource_pool.cloud_properties).to eq({})
        end
      end

      %w(size).each do |key|
        context "when #{key} is missing" do
          before { valid_spec.delete(key) }

          it 'does not raise an error' do
            expect { ResourcePool.new(plan, valid_spec, logger) }.to_not raise_error
          end
        end
      end

      context 'when the deployment plan does not have the resource pool network' do
        before do
          valid_spec.merge!('network' => 'foobar')
          allow(plan).to receive(:network).with('foobar').and_return(nil)
        end

        it 'raises an error' do
          expect { ResourcePool.new(plan, valid_spec, logger) }.to raise_error(BD::ResourcePoolUnknownNetwork)
        end
      end

      context 'when the resource pool spec has no env' do
        before { valid_spec.delete('env') }

        it 'has default env' do
          expect(resource_pool.env).to eq({})
        end
      end
    end

    it 'returns resource pool spec as Hash' do
      expect(resource_pool.spec).to eq({
        'name' => 'small',
        'cloud_properties' => { 'foo' => 'bar' },
        'stemcell' => { 'name' => 'stemcell-name', 'version' => '0.5.2' }
      })
    end

    describe '#reserve_dynamic_networks' do
      let(:network_reservation) { instance_double('Bosh::Director::NetworkReservation') }
      before do
        2.times { resource_pool.allocate_vm }
        resource_pool.allocated_vms.first.use_reservation(network_reservation)
      end

      it 'attempts to create reservations on vms without them' do
        expect(Bosh::Director::NetworkReservation).to receive(:new_dynamic).with(no_args).and_return(network_reservation)
        expect(network).to receive(:reserve!).with(network_reservation, nil)

        expect(resource_pool.allocated_vms.last).to receive(:network_reservation=).with(network_reservation)

        resource_pool.reserve_dynamic_networks
      end

      it 'raises an error when network reservation fails' do
        expect(Bosh::Director::NetworkReservation).to receive(:new_dynamic).with(no_args).and_return(network_reservation)
        expect(network).to receive(:reserve!).with(network_reservation, nil).
          and_raise(Bosh::Director::NetworkReservationError)
        expect {
          resource_pool.reserve_dynamic_networks
        }.to raise_error(Bosh::Director::NetworkReservationError)
      end

      it 'raises an error when network reservation fails with not enough capacity' do
        expect(Bosh::Director::NetworkReservation).to receive(:new_dynamic).with(no_args).and_return(network_reservation)
        expect(network).to receive(:reserve!).with(network_reservation, nil).
          and_raise(Bosh::Director::NetworkReservationNotEnoughCapacity)
        expect {
          resource_pool.reserve_dynamic_networks
        }.to raise_error(Bosh::Director::NetworkReservationNotEnoughCapacity)
      end
    end

    describe '#allocate_vm' do
      context 'when resource pool is dynamically sized' do
        before { valid_spec.delete('size') }

        it 'creates a new vm if dynamically sized' do
          allocated_vm = resource_pool.allocate_vm
          allocated_vm.model = instance_double('Bosh::Director::Models::Vm', cid: 'abc')

          expect(resource_pool.allocated_vms).to eq([allocated_vm])
        end
      end
    end

    describe '#deallocate_vm' do
      context 'when resource pool is dynamically sized' do
        before { valid_spec.delete('size') }

        context 'when the pool contains an allocated vm' do
          let(:vm_model) { instance_double('Bosh::Director::Models::Vm', cid: 'abc') }

          before do
            @allocated_vm = resource_pool.allocate_vm
            @allocated_vm.model = vm_model
          end

          it 'removes vm from allocated' do
            resource_pool.deallocate_vm(vm_model.cid)
            expect(resource_pool.allocated_vms).to be_empty
          end
        end

        context 'when the pool does not contain any allocated vms' do
          it 'raises an error' do
            expect{
              resource_pool.deallocate_vm('abc')
            }.to raise_error(
              Bosh::Director::DirectorError,
              /Resource pool `small' does not contain an allocated VM with the cid `abc'/,
            )
          end
        end
      end
    end
  end
end

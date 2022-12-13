
class AeonRequestController < ApplicationController
  protect_from_forgery with: :exception
  def popup
    uri = params[:uri]

    my_logger = Logger.new("yale_as_requests_controller_popup.log")



    my_logger.info("URI: #{uri}")
    return render status: 400, plain: 'uri param required' if uri.nil?
    my_logger.info("got to return render")
    parsed_uri = JSONModel.parse_reference(uri)

    if parsed_uri.fetch(:type) == 'archival_object'
      # we want to pull back the PUI version of the AO
      uri = "#{uri}#pui"
    end

    record = archivesspace.get_record(uri, {
      'resolve[]' => ['repository:id', 'resource:id@compact_resource', 'top_container_uri_u_sstr:id', 'linked_instance_uris:id', 'digital_object_uris:id'],
    })

    my_logger.info("Got record-Record: " + record.to_s)
    mapper = AeonRecordMapper.mapper_for(record)

    my_logger.info("mapper: " + mapper.inspect)
    #request_type = 'reading_room'
    request_type = params[:request_type].to_s.empty? ? nil : params[:request_type]

    #my_logger.info("request type: " + request_type)
    return render status: 400, plain: 'Action not supported for record' if mapper.hide_button?
    return render status: 400, plain: 'Action not available for record' unless mapper.show_action?

    if request_type
      return render status: 400, plain: 'Request type not available for record' unless mapper.available_request_types.any?{|rt| rt.fetch(:request_type) == request_type}

      mapper.request_type = request_type

    elsif AeonRecordMapper.is_digital_only(record)
      mapper.request_type = 'digitization'
    else
      mapper.request_type = mapper.available_request_types.first.fetch(:request_type)
    end



    

    my_logger.info("record: " + mapper.inspect)
    my_logger.info("mapper: " + mapper.inspect)
    #my_logger.info("finding aid view: " + params[:finding_aid_view].to_s == 'true'.to_s)

    request_type_config = mapper.available_request_types.detect{|rt| rt.fetch(:request_type) == params[:request_type]}
    my_logger.info("request_type_config: " + request_type_config.to_s)
    render partial: 'aeon/aeon_request_popup', locals: {
      record: record,
      mapper: mapper,
      #finding_aid_view: params[:finding_aid_view].to_s == 'true',
      request_type_config: request_type_config,
    }
    my_logger.info("mapper after render: " + mapper.inspect)
    my_logger.info("got past render partial ... popup")
  end

  def build
    my_logger = Logger.new("yale_as_requests_controller_build.log")

    uri = params[:uri]

    return render status: 400, plain: 'uri param required' if uri.nil?

    parsed_uri = JSONModel.parse_reference(uri)

    if parsed_uri.fetch(:type) == 'archival_object'
      # we want to pull back the PUI version of the AO
      uri = "#{uri}#pui"
    end

    record = archivesspace.get_record(uri, {
      'resolve[]' => ['repository:id', 'resource:id@compact_resource', 'top_container_uri_u_sstr:id', 'linked_instance_uris:id', 'digital_object_uris:id'],
    })

    mapper = AeonRecordMapper.mapper_for(record)

    return render status: 400, plain: 'Action not supported for record' if mapper.hide_button?
    return render status: 400, plain: 'Action not available for record' unless mapper.show_action?

    request_type_config = mapper.available_request_types.detect{|rt| rt.fetch(:request_type) == params[:request_type]}

    return render status: 400, plain: "Unknown request type: #{params[:request_type]}" if request_type_config.nil?

    mapper.requested_instance_indexes = (params[:instance_idx] || []).map{|idx| Integer(idx)}
    mapper.request_type = request_type_config.fetch(:request_type)

    render partial: 'aeon/aeon_request', locals: {
      record: record,
      mapper: mapper,
      request_type_config: request_type_config,
    }
  end
end

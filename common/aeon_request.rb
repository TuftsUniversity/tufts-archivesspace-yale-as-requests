require 'nokogiri'
require 'net/http'
require 'json'

require_relative 'aeon_archival_object_request'
require_relative 'aeon_top_container_request'


def parse_sub_container_display_string_yale_as_requests(sub_container, inst, opts = {})
  summary = opts.fetch(:summary, false)
  citation = opts.fetch(:citation, false)
  parts = []

  instance_type = I18n.t("enumerations.instance_instance_type.#{inst.fetch('instance_type')}", :default => inst.fetch('instance_type'))

  # add the top container type and indicator
  if sub_container.has_key?('top_container')
    top_container_solr = get_record_plain(sub_container['top_container']['ref'])
    #top_container_solr = top_container_for_uri(sub_container['top_container']['ref'])
    if top_container_solr
      # We have a top container from Solr
      top_container_display_string = ""
      top_container_json = ASUtils.json_parse(top_container_solr.fetch('json'))
      if top_container_json['type']
        top_container_type = I18n.t("enumerations.container_type.#{top_container_json.fetch('type')}", :default => top_container_json.fetch('type'))
        top_container_display_string << "#{top_container_type}: "
      else
        top_container_display_string << "#{I18n.t('enumerations.container_type.container')}: "
      end
      top_container_display_string << top_container_json.fetch('indicator')
      parts << top_container_display_string
    elsif sub_container['top_container']['_resolved'] && sub_container['top_container']['_resolved']['display_string']
      # We have a resolved top container with a display string
      parts << sub_container['top_container']['_resolved']['display_string']
    end
  end
end

def build_instance_display_string(instance)
  if sc = instance.fetch('sub_container', nil)
    parse_sub_container_display_string_yale_as_requests(sc, instance)
  elsif digital_object = instance.dig('digital_object', '_resolved')
    digital_object.fetch('title')
  else
    raise "Instance not supported: #{instance}"
  end
end


class AeonRequest
  
  def self.get_record_plain(uri)
    JSONModel::HTTP.get_json(URI.encode(uri))
  end
      
  def self.request_for(json)
    {
      'archival_object' => AeonArchivalObjectRequest,
      'top_container' => AeonTopContainerRequest,
    }[json['jsonmodel_type']]
  end

  def self.config_for(json)
    repo_code = json.dig('repository','_resolved','repo_code')

    raise "No resolved repository on record: #{json['uri']}" if repo_code.nil?

    # force lowercase as per original aeon_fulfillment plugin
    repo_code = repo_code.downcase

    if AppConfig[:aeon_fulfillment].has_key?(repo_code)
      AppConfig[:aeon_fulfillment].fetch(repo_code)
    else
      raise "No AppConfig[:aeon_fulfillment] entry for repo: #{repo_code}"
    end
  end

  def self.build(json, opts = {})

    out = {}

    cfg = config_for(json)

    # if (loc = json['container_locations'].find{|cl| cl['status'] == 'current'})
    #   # FIXME: locations are not resolved in the pui index json for aos and there seems to be
    #   #        no way to resolve them without getting the top_containers individually (which do have them resolved)
    #   #        so skipping for now if we lack '_resolved'.
    #   request["Location"] = loc['_resolved']['title'].sub(/\[\d{5}, /, '[') if loc['_resolved']
    #   request['instance_top_container_long_display_string'] = request['Location']
    #
    #   # ItemInfo11 (location uri)
    #   request["ItemInfo11"] = loc['ref']
    # else
    #   # added this so that we don't wind up with the default Aeon mapping here, which maps the top container long display name to the location.
    #   request['instance_top_container_long_display_string'] = nil
    # end
    out['repo_code'] = json['repository']['_resolved']['repo_code']
    out['repo_name'] = json['repository']['_resolved']['name']

    out['SystemID'] = cfg.fetch(:aeon_external_system_id, "ArchivesSpace")
    out['ReturnLinkURL'] = "#{AppConfig[:public_proxy_url]}#{json['uri']}"
    out['ItemInfo3'] = "#{AppConfig[:public_proxy_url]}#{json['uri']}"
    out['ReturnLinkSystemName'] = cfg.fetch(:aeon_return_link_label, "ArchivesSpace")
    out['Site'] = cfg.fetch(:aeon_site_code, '')

    out['EADNumber'] = out['ReturnLinkURL']

    out['uri'] = json['uri']
    string = json['display_string']



    # FIXME: creators?
    # out['creators'] = ???

    # FIXME: language?
    # out['language'] = json['language']

    out['display_string'] = json['display_string']


    request_for(json).build(json, out, opts)
  end


  def self.build_requests(instances, component_id)
    instances.map do |instance|
      request = {}

      request["instance_is_representative"] = instance['is_representative']
      request["instance_last_modified_by"] = instance['last_modified_by']
      request["instance_instance_type"] = instance['instance_type']
      request["instance_created_by"] = instance['created_by']

      container = instance['sub_container']
      next request unless container

      request["instance_container_grandchild_indicator"] = container['indicator_3']
      request["instance_container_child_indicator"] = container['indicator_2']
      request["instance_container_grandchild_type"] = container['type_3']
      request["instance_container_child_type"] = container['type_2']
      request["instance_container_last_modified_by"] = container['last_modified_by']
      request["instance_container_created_by"] = container['created_by']

      request["instance_top_container_ref"] = container['top_container']['ref']

      request['ItemEdition'] = ['2', '3'].map {|lvl|
        (container["type_#{lvl}"] || '').downcase == 'folder' ? container["indicator_#{lvl}"] : nil
      }.compact.join('; ')

      request['ItemISxN'] = ['2', '3'].map {|lvl|
        (container["type_#{lvl}"] || '').downcase == 'item_barcode' ? container["indicator_#{lvl}"] : nil
      }.compact.join('; ')


      begin
		  AeonRequest.build_top_container(container['top_container']['_resolved'], request, component_id)

		  request.delete_if{|k,v| v.nil? || v.is_a?(String) && v.empty?}
		  
	  rescue
	     print("digital object")
		 
	  end
      ##my_logger = Logger.new("yale_as_requests_common.log")
      ##my_logger.info("request: #{request.to_s}")
      request
    end
  end

  def self.build_top_container(json, request, component_id)
    # tidy up series display strings before we start
    #request["Transaction.CustomFields.BoxNumber"] = json['display_string']
    # request["Location"] = json['long_display_string']
    # string = json['long_display_string']
    # string = string.gsub(/^.+?(Box)[^\d]+(\d+).+$/, '\1 \2')
    #
    # #UP029, Series UP056.001; Series UP029.022, Volume Shared 134 [39090011484660y]"
    #                                                   #Box+1%3A+Series+UA002.001+%5BIM+721202868%5D
    # if !string.empty?
    #   request['Transaction.CustomFields.BoxNumber'] = string
    # end
    json['series'].each { |s| s['display_string'] = AeonRequest.strip_mixed_content(s['display_string']) }

    request["instance_top_container_long_display_string"] = json['long_display_string']
    request["instance_top_container_last_modified_by"] = json['last_modified_by']
    request["instance_top_container_display_string"] = json['display_string']
    request["instance_top_container_restricted"] = json['restricted']
    request["instance_top_container_created_by"] = json['created_by']
    request["instance_top_container_indicator"] = json['indicator']
    request["instance_top_container_barcode"] = json['barcode']
    request["instance_top_container_type"] = json['type']
    #string = json['display_string']
    #request['Transaction.CustomFields.BoxNumber'] = string.gsub(/^(Box\+\d+).+$/, '\1')

      #  out['Transaction.CustomFields.BoxNumber'] = string.gsub(/^(Box\+\d+).+$/, '\1')

      #  "long_display_string" : "UA002, Series UA002.001, Box 1 [IM 721202868]"


    request["instance_top_container_collection_identifier"] = json['collection'].map { |c| c['identifier'] }.join("; ")
    request["instance_top_container_collection_display_string"] = json['collection'].map { |c| c['display_string'] }.join("; ")

    request["instance_top_container_series_identifier"] = json['series'].map { |s| s['identifier'] }.join("; ")
    request["instance_top_container_series_display_string"] = json['series'].map { |s| s['display_string'] }.join("; ")

    #request["ReferenceNumber"] = request["instance_top_container_barcode"]

    request['ItemInfo1'] = json['restricted'] ? 'Y' : 'N'

    #request['ItemVolume'] = json['display_string'][0, (json['display_string'].index(':') || json['display_string'].length)]
	request['ItemVolume'] = component_id

    request['ItemInfo10'] = json['uri']
    request["ItemIssue"] = json['series'].map{|s| s['level_display_string'] + ' ' + s['identifier'] + '. ' + s['display_string']}.join('; ')



    request
  end

  # adapted from the original record mapper
  # not sure if it is used at yale so removing for now
  # untested!
  def self.build_user_defined_fields(udf)
    if (udf_setting = cfg[:user_defined_fields])
      if user_defined_fields = json['user_defined']
        if udf_setting == true
          is_whitelist = false
          fields = []
        else
          if udf_setting.is_a?(Array)
            is_whitelist = true
            fields = udf_setting
          else
            is_whitelist = udf_setting[:list_type].intern == :whitelist
            fields = udf_setting[:values] || udf_setting[:fields] || []
          end
        end

        user_defined_fields.each do |field_name, value|
          if (is_whitelist ? fields.include?(field_name) : fields.exclude?(field_name))
            out["user_defined_#{field_name}"] = value
          end
        end
      end
    end
  end


  # from yale_aeon_utils

  def self.doc_type(json, id)
    resource_id_map(config_for(json)[:document_type_map], id)
  end


  def self.web_request_form(json, id)
    resource_id_map(config_for(json)[:web_request_form_map], id)
  end


  def self.resource_id_map(id_map, id)
    return '' unless id_map

    default = id_map.fetch(:default, '')

    if id
      val = id_map.select {|k,v| id.start_with?(k.to_s)}.values.first
      return val if val
    end

    return default
  end


  def self.local_access_restrictions(notes)
    notes.select {|n| n['type'] == 'accessrestrict' && n.has_key?('rights_restriction')}
         .map {|n| n['rights_restriction']['local_access_restriction_type']}
         .flatten.uniq.join(' ')
  end


  def self.access_restrictions_content(notes)
    notes.select {|n| n['type'] == 'accessrestrict'}
         .map {|n| n['subnotes'].map {|s| s['content']}.join(' ')}
         .join('; ')
  end

  def self.content_warning_content(notes)
    notes.select {|n| n['type'] == 'scopecontent' && (n['label'] == 'Content Warning' || n['label'] == 'Content warning')}
         .map {|n| n['subnotes'].map {|s| s['content']}.join(' ')}
         .join('; ')
  end

  def self.archivesspace

      ArchivesSpaceClient.instance
  end

  def self.containers(instances, locations)
    #my_logger = Logger.new("yale_as_requests_common_aeon_request_container.log")
    #my_logger.info("instances: #{instances.to_s}")
    container_numbers = []
    container_locations = []
    container_barcodes = []
    return_dict = {}

    instances.each do |instance |
      begin
        json = instance['sub_container']['top_container']['_resolved']

        string = json['display_string']
        string = string.gsub(/^(.+?)\:.+$/, '\1')
        if !string.empty?
          container_numbers << string
        end
        #my_logger.info("\nbox: #{string}")


        #my_logger.info("\nlocation: #{json['long_display_string']}")
        # if (json['container_location']['status'] == 'current')
        #
        # end
      #  container_locations << json['long_display_string']
          #my_logger.info("barcodes: #{json['barcode']}")
        container_barcodes << json['barcode']
        #my_logger.info("\n\n")
        #my_logger.info("location: #{json['container_locations'].to_s}")
        json['container_locations'].each do |loc|
         #my_logger.info("\n\n")
         #my_logger.info("loc: #{loc}")
         #my_logger.info("location: #{loc.to_s}")
          if loc['status'] == 'current'
            ref = loc['ref']
            #my_logger.info("\n\n")
            #my_logger.info("location ref data type: #{ref.class}")

            #test_archival_object_ref = "/repositories/2/archival_objects/116961"

            #test_archival_object = archivesspace.get_record(test_archival_object_ref)
            #my_logger.info("\n\n\n\n")
            #my_logger.info("test archival object 116961: #{test_archival_object.to_s}")
            #my_logger.info("location ref: #{ref}")
            location = self.get_record_plain(ref)
            #my_logger.info("location retrieved from location record: #{location.inspect}")
            title = location['title']

            title = title.gsub(/([^,]+),([^,]+),([^\[]+).+?,(\s+[^,]+,\s+[^,]+,\s+.+?)\]/, 'Room:\3,\4')
            container_locations << title
          end

        end
      rescue
        random_variable = ""
      end

    end


    # locations.each do | loc |
    #   # begin
    #       if (loc['status'] == 'current')
    #
    #         ref = loc['ref']
    #
    #         location = archvivesspace.get_record(ref)
    #
    #         title = location['title']
    #
    #         container_locations << title
    #       end
    #   # rescue
    #     other_variable = ""
    #   # end
    #
    # end


    if container_barcodes.length == 0 && container_locations == 0 && container_numbers.length == 0
      #my_logger.info("all arrays are empty")
      return_dict = {"container_numbers": "", "container_locations": "", "container_barcodes": ""}
    else
      return_dict = {"container_numbers": container_numbers.join(";"), "container_locations": container_locations.join(";"), "container_barcodes": container_barcodes.join(";")}
    end
    #my_logger.info("return_dict: #{return_dict}")
    return return_dict
  end

  # def self.get_resource_ead_id(uri)
  #   resource_record = archivesspace.get_record(uri)
  #
  #   ead_id = resource_record['ead_id']
  #
  #   return ead_id
  #
  # end

  # nicked verbatim from the pui
  def self.strip_mixed_content(in_text)
    return if !in_text

    # Don't fire up nokogiri if there's no mixed content to parse
    unless in_text.include?("<")
      return in_text
    end

    in_text = in_text.gsub(/ & /, ' &amp; ')
    @frag = Nokogiri::XML.fragment(in_text)

    @frag.content
  end

end

class AeonArchivalObjectRequest

  def self.archivesspace

    ArchivesSpaceClient.instance
  end
  # kind of replicating some pui madness - gross
  def self.citation(json, mapped)
    cite = ''
    if note = json['notes'].find{|n| n['type'] == 'prefercite'}
      cite = note['subnotes'].map{|sn| sn['content']}.join('; ')
    else
      cite = "#{json['component_id']}, " if json['component_id']
      cite += mapped['title']

      cite += ', '
      cite += json['instances'].select { |i| i['sub_container'] }.map { |i|
      sc = i['sub_container']
      tc = sc['top_container']['_resolved']

      base = (tc['type'] ? I18n.t("enumerations.container_type.#{tc['type']}", default: tc['type']) : 'Container') + ': ' + tc['indicator']

      suffix = ['2', '3'].select { |l| sc["indicator_#{l}"] }.map { |l|
       ', ' + (sc["type_#{l}"] ? I18n.t("enumerations.container_type.#{sc["type_#{l}"]}", default: sc["type_#{l}"]) : 'Container') +
       ': ' + sc["indicator_#{l}"]
      }.join

        onsite = tc['onsite_status'] ? " - #{tc['onsite_status'].capitalize}" : ''

        base + suffix + onsite
      }.join('; ')


      cite += ". #{mapped['collection_title']}, #{mapped['collection_id']}. #{mapped['repo_name']}."
    end

    "#{cite}  #{AppConfig[:public_proxy_url]}#{json['uri']}  Accessed #{Time.now.strftime("%B %d, %Y")}"
  end


  def self.build(json, request, opts = {})
    out = request

    out['identifier'] = json['component_id']
  	#out['ItemInfo4'] = json['component_id']
	  out['ItemNumber'] = json['component_id']

    out['publish'] = json['publish']

    out['level'] = I18n.t('enumerations.archival_record_level.' + json['level'], :default => json['level'])

    out['title'] = AeonRequest.strip_mixed_content(json['title'])

    resource = opts[:resource] || json['resource']['_resolved']
    out['collection_id'] = [0,1,2,3].map{|ix| resource["id_#{ix}"]}.compact.join('-')
    out['collection_title'] = resource['title']

    out['repository_processing_note'] = json['repository_processing_note'] if json['repository_processing_note']

    out['physical_location_note'] = json['notes']
      .select { |note| note['type'] == 'physloc' and note['content'].present? }
      .map { |note| note['content'] }
      .flatten
      .join("; ")

    out['accessrestrict'] = AeonRequest.access_restrictions_content(json['notes'])

    json['dates']
      .select { |date| date.has_key?('expression') }
      .group_by { |date| date['label'] }
      .each { |label, dates|
        out["#{label}_date"] = dates.map { |date| date['expression'] }.join("; ")
      }

    resource_record = self.archivesspace.get_record(json['resource']['ref'])

    #my_logger = Logger.new("yale_as_requests_ae_request.log")

  
    ead_id = resource_record['ead_id']
    out['restrictions_apply'] = json['restrictions_apply']

    out['ItemInfo14'] = json['resource']['ref']

    creator = json['linked_agents'].find{|a| a['role'] == 'creator'}

    out['ItemAuthor'] = creator['_resolved']['title'] if creator
    out['ItemInfo1'] = AeonRequest.access_restrictions_content(json['notes'])

    out['ItemInfo6'] = json['notes'].select {|n| n['type'] == 'userestrict'}
      .map {|n| n['subnotes'].map {|s| s['content']}.join(' ')}
      .join(' ')

    out['ItemInfo7'] = json['extents'].select {|e| !e.has_key?('_inherited')}
      .map {|e| "#{e['number']} #{e['extent_type']}"}.join('; ')
    my_logger = Logger.new("yale_as_archival_objects_common.log")
    out['ItemInfo8'] = AeonRequest.local_access_restrictions(json['notes'])
    out['Transaction.CustomFields.ContentWarning'] = AeonRequest.content_warning_content(json['notes'])
    instance_dict = AeonRequest.containers(json['instances'], json['container_locations'])
    my_logger.info("instance_dict #{instance_dict.inspect}")

    out['Transaction.CustomFields.Container'] = instance_dict["container_numbers"]
    out["Transaction.CustomFields.StorageLocation"] = instance_dict["container_locations"]
    out["Transaction.CustomFields.CollectionRestriction"] = AeonRequest.get_collection_restriction(resource_record['notes'])
    
 
    #out["ItemNumber"] = instance_dict[:container_barcodes]
    out["ItemNumber"] = instance_dict["container_barcodes"]

    out['ItemVolume'] = json['component_id']

    out['component_id'] = json['component_id']
    out['ItemTitle'] = out['collection_title']
    out['DocumentType'] = AeonRequest.doc_type(json, out['collection_id'])
    out['WebRequestForm'] = AeonRequest.web_request_form(json, out['collection_id'])
    out['ItemSubTitle'] = out['title']
    out['ItemCitation'] = citation(json, out)

    reference_number = json['component_id'].dup
    reference_number.gsub!(/^([^\.-]+).+/, '\1')



    out['ItemDate'] = json['dates'].map {|d|
      #I18n.t("enumerations.date_label.#{d['label']}") + '  ' + (d['expression'] || ([d['begin'], d['end']].compact.join(' - ')))
      (d['expression'] || ([d['begin'], d['end']].compact.join(' - ')))
    }.join(', ')

    out['ItemInfo13'] = out['component_id']

    json['external_ids'].select{|ei| ei['source'] == 'local_surrogate_call_number'}.map do |ei|
      out['collection_id'] += '; ' + ei['external_id']
    end

    out['CallNumber'] = out['collection_id']


    out['requests'] = AeonRequest.build_requests(opts.fetch(:selected_container_instances, json['instances']), json['component_id'])

    # ? Add this line:
    #out[:custom_fields] = out.select { |k, _| k.start_with?("Transaction.CustomFields.") }



    out
  end
end

class AeonArchivalObjectRequest

  # kind of replicating some pui madness - gross
  def self.citation(json, mapped)
    cite = ''
    if note = json['notes'].find{|n| n['type'] == 'prefercite'}
      cite = note['subnotes'].map{|sn| sn['content']}.join('; ')
    else
      cite = "#{json['component_id']}, " if json['component_id']
      cite += mapped['title']

      cite += ', '
      cite += json['instances'].select{|i| i['sub_container']}.map{|i|
        sc = i['sub_container']
        tc = sc['top_container']['_resolved']
        (tc['type'] ? I18n.t("enumerations.container_type.#{tc['type']}", :default => tc['type']) : 'Container') + ': ' + tc['indicator'] +
        ['2', '3'].select{|l| sc["indicator_#{l}"]}.map{|l|
          ', ' + (sc["type_#{l}"] ? I18n.t("enumerations.container_type.#{sc["type_#{l}"]}", :default => sc["type_#{l}"]) : 'Container') +
          ': ' + sc["indicator_#{l}"]
        }.join +
        ' - ' + tc['onsite_status'].capitalize
      }.join('; ')

      cite += ". #{mapped['collection_title']}, #{mapped['collection_id']}. #{mapped['repo_name']}."
    end

    "#{cite}  #{AppConfig[:public_proxy_url]}#{json['uri']}  Accessed #{Time.now.strftime("%B %d, %Y")}"
  end


  def self.build(json, request, opts = {})
    out = request

    out['identifier'] = json['component_id']

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
      #
      location_array = []
      box_array = []
      series_ref = ""

      json['instances'].each do |instance|

        container = instance['sub_container']['top_container']['_resolved']


        location_array << container['long_display_string']

        string = container['long_display_string']
        string = string.gsub(/^([^:]+):.+$/, '\1')

        if string.empty?
          #out['box_number'] = ""
          box_array << ""
        else
          #out['box_number'] = string
          box_array << string
        end
        ### hold on to this

        container['series'].each do |s|
          if /#{s['identifier']}/.match(s)
            series_ref = s['ref']
          end

        end
        #series << {"identifier": s['identifier'], "ref": s['ref']}

        # if s['identifier']
        #   container = instance['sub_container']['top_container']['_resolved']
        #
        # #  out["Location"] = container['long_display_string']
        #   location_array <<  container['long_display_string']
        #   string = container['long_display_string']
        #   string = string.gsub(/^.*(Box)[^\d]+(\d+).+$/, '\1 \2')
        #
        #
        #   #UP029, Series UP056.001; Series UP029.022, Volume Shared 134 [39090011484660y]"
        #                                                     #Box+1%3A+Series+UA002.001+%5BIM+721202868%5D
        #   if string.empty?
        #     #out['box_number'] = ""
        #     box_array << ""
        #   else
        #     #out['box_number'] = string
        #     box_array << string
        #   end
      end
      # request['series_array'] = series

    series_ao_json = archivesspace.get_record(series_ref)


    out['content_warning'] = AeonRequest.content_warning_content(json['notes'], json, series_ao_json['notes'])



    out['Location'] = location_array.join(";")
    out['box_number'] = box_array.join(";")
    out['accessrestrict'] = AeonRequest.access_restrictions_content(json['notes'])

    json['dates']
      .select { |date| date.has_key?('expression') }
      .group_by { |date| date['label'] }
      .each { |label, dates|
        out["#{label}_date"] = dates.map { |date| date['expression'] }.join("; ")
      }

    out['restrictions_apply'] = json['restrictions_apply']

    out['ItemInfo14'] = json['resource']['ref']

    creator = json['linked_agents'].find{|a| a['role'] == 'creator'}

    out['ItemAuthor'] = creator['_resolved']['title'] if creator
    out['ItemInfo5'] = AeonRequest.access_restrictions_content(json['notes'])

    out['ItemInfo6'] = json['notes'].select {|n| n['type'] == 'userestrict'}
      .map {|n| n['subnotes'].map {|s| s['content']}.join(' ')}
      .join(' ')

    out['ItemInfo7'] = json['extents'].select {|e| !e.has_key?('_inherited')}
      .map {|e| "#{e['number']} #{e['extent_type']}"}.join('; ')

    out['ItemInfo8'] = AeonRequest.local_access_restrictions(json['notes'])
    #out['content_warning'] = AeonRequest.content_warning_content(json['notes'], json)


    out['component_id'] = json['component_id']
    out['ItemTitle'] = out['collection_title']
    out['DocumentType'] = AeonRequest.doc_type(json, out['collection_id'])
    out['WebRequestForm'] = AeonRequest.web_request_form(json, out['collection_id'])
    out['ItemSubTitle'] = out['title']
    out['ItemCitation'] = citation(json, out)

    out['ItemDate'] = json['dates'].map {|d|
      I18n.t("enumerations.date_label.#{d['label']}") + '  ' + (d['expression'] || ([d['begin'], d['end']].compact.join(' - ')))
    }.join(', ')

    out['ItemInfo13'] = out['component_id']

    json['external_ids'].select{|ei| ei['source'] == 'local_surrogate_call_number'}.map do |ei|
      out['collection_id'] += '; ' + ei['external_id']
    end

    out['CallNumber'] = out['collection_id']


    out['requests'] = AeonRequest.build_requests(opts.fetch(:selected_container_instances, json['instances']))




    out
  end
  #
  # def self.content_warning_content(notes, json)
  #   notes.select {|n| n['type'] == 'scopecontent' && (n['label'] == 'Content Warning' || n['label'] == 'Content warning')}
  #        .map {|n| n['subnotes'].map {|s| s['content']}.join(' ')}
  #        .join('; ')
  #
  #   if (notes.empty?)
  #
  #   end
  # end
end

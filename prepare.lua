local t = ...

-- Filter the testcase XML with the VCS ID.
t:filterVcsId('../..', '../../muhkuh_webui.xml', 'muhkuh_webui.xml')

return true

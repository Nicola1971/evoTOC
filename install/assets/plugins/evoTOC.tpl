//<?php
/**
 * evoTOC
 *
 * Plugin for automatically creating a table of contents on a page using anchors.
 *
 * @author    Nicola Lambathakis http://www.tattoocms.it/
 * @category    plugin
 * @version     1.0.0
 * @license     http://www.gnu.org/copyleft/gpl.html GNU Public License (GPL)
 * @internal    @properties &lStart=Start level;list;1,2,3,4,5,6;2 &lEnd=End level;list;1,2,3,4,5,6;3 &table_name=Transliteration;list;common,russian;common &tocTitle=Title;string;Contents &tocClass=CSS class;string;toc &tocAnchorType=Anchor type;list;1,2;1 &tocAnchorLen=Maximum anchor length;number;0 &include_templates=Include only these Templates by id (comma separated);string; &exclude_docs=Exclude Documents by id (comma separated);string; &exclude_templates=Exclude Templates by id (comma separated);string; &addBackToTop=Enable back to top;list;no,yes;no &backToTopText=Back to top text;string;Back To Top &backToTopTitle=Back to top title attribute;string;Back To Top &backToTopClass=Back to top CSS class;string;toc-back-to-top &backToTopLevels=Back to top on headings (comma separated);string;2
 * @internal    @events OnLoadWebDocument
 * @internal    @modx_category Content
 * @internal    @legacy_names evoTOC
 * @internal    @installset base, sample
 */

if(!defined('MODX_BASE_PATH')){die('What are you doing? Get out of here!');}

global $modx;

$include_templates = isset($include_templates) ? explode(',', $include_templates) : array();
$exclude_docs = explode(',',$exclude_docs);
$exclude_templates = explode(',',$exclude_templates);
// clean up arrays
$include_templates = array_filter(array_map('trim', $include_templates));
$exclude_docs = array_filter(array_map('trim', $exclude_docs));
$exclude_templates = array_filter(array_map('trim', $exclude_templates));

$doc_id = $modx -> documentObject['id'];
$template_id = $modx -> documentObject['template'];

// Check if we should process this document
$should_process = true;

// If include_templates is not empty, check if current template is included
if (!empty($include_templates)) {
    $should_process = in_array($template_id, $include_templates);
}

// If we should process and there are exclusions, check them
if ($should_process) {
    if (in_array($doc_id, $exclude_docs) || in_array($template_id, $exclude_templates)) {
        $should_process = false;
    }
}

if ($should_process) {
    $lStart = isset($lStart) ? $lStart : 2;
    $lEnd = isset($lEnd) ? $lEnd : 3;
    $tocTitle = isset($tocTitle) ? $tocTitle : '';
    $tocClass = isset($tocClass) ? $tocClass : 'toc';
    $tocAnchorType = (isset($tocAnchorType) and ($tocAnchorType == 2)) ? 2 : 1;
    $tocAnchorLen = (isset($tocAnchorLen) and ($tocAnchorLen > 0)) ? $tocAnchorLen : 0;
    // Convert yes/no to boolean for back to top feature
    $addBackToTop = (isset($addBackToTop) && $addBackToTop === 'yes');
    $backToTopText = isset($backToTopText) ? $backToTopText : 'Back To Top';
    $backToTopClass = isset($backToTopClass) ? $backToTopClass : 'toc-back-to-top';
    // Parse back to top levels
    $backToTopLevels = isset($backToTopLevels) ? explode(',', $backToTopLevels) : array('2');
    $backToTopLevels = array_map('trim', $backToTopLevels); // Remove any whitespace
    
    // Transliteration setup
    $plugin_path = MODX_BASE_PATH.'assets/plugins/transalias';
    $table_name = isset($table_name) ? $table_name : 'russian';

    if (!class_exists('TransAlias')) {
        require_once $plugin_path.'/transalias.class.php';
    }
    $trans = new TransAlias($modx);

    $tocResult = ''; 
    $hArray = array(); // results array
    $cont = $modx->documentObject['content'];
    
    // Add a named anchor at the top of the table of contents if back to top is enabled
    if ($addBackToTop) {
        $tocResult .= '<div id="table-of-contents"></div>';
    }
    
    // Use preg_match_all instead of manual string parsing
    $pattern = "/<h([2-6])(.*?)>(.*?)<\/h[2-6]>/si";
    if (preg_match_all($pattern, $cont, $matches, PREG_SET_ORDER | PREG_OFFSET_CAPTURE)) {
        foreach ($matches as $match) {
            $hLevel = $match[1][0];  // The heading level (2-6)
            $hContent = $match[0][0]; // The full heading tag
            $position = $match[0][1]; // The position in the content
            
            if ($hLevel >= $lStart && $hLevel <= $lEnd) {
                // Check for existing anchor
                $hasAnchor = preg_match("/<a [\s\S]*?name=\"([\w]+)\"/", $hContent, $getAnchor);
                
                $anchorName = '';
                if ($hasAnchor) {
                    $anchorName = $getAnchor[1];
                } else {
                    // Generate anchor name
                    if ($tocAnchorType == 2) {
                        $anchorName = $position;
                    } else {
                        if ($trans->loadTable($table_name,'Yes')) {
                            $anchorName = $trans->stripAlias(strip_tags($hContent),'lowercase alphanumeric','-');
                            if ($tocAnchorLen > 0) {
                                $anchorName = substr($anchorName, 0, $tocAnchorLen);
                            }
                        } else {
                            $anchorName = $position;
                        }
                    }
                    
                    // Insert anchor into heading
                    $modifiedHeading = preg_replace(
                        "/<h(" . $hLevel . ")(.*?)>/",
                        "<h$1$2><a name=\"" . $anchorName . "\"></a>",
                        $hContent
                    );

                    // Add "back to top" link after the heading if enabled and level is included
                    if ($addBackToTop && in_array($hLevel, $backToTopLevels)) {
                        $backToTopLink = " <div class=\"" . $backToTopClass . "-container\"><a title=\"$backToTopTitle\" href=\"[~[*id*]~]#table-of-contents\" class=\"" . $backToTopClass . "\">" . $backToTopText . "</a></div>";
                        $modifiedHeading = $modifiedHeading . $backToTopLink;
                    }

                    $cont = str_replace($hContent, $modifiedHeading, $cont);
                }
                
                $hArray[] = array(
                    'level' => $hLevel,
                    'header_in' => $hContent,
                    'anchor' => $anchorName
                );
            }
        }
    }

    // Create table of contents
    if(count($hArray) > 0) {
        $curLev = 0;
        foreach ($hArray as $key => $value) {
            if($curLev == 0) {
                $tocResult .= '<ul class="' . $tocClass . '_' . $value['level'] . '">';
            } elseif($curLev != $value['level']) {
                if($curLev < $value['level']) {
                    $tocResult .= '<ul class="lev2 ' . $tocClass . '_' . $value['level'] . '">';
                } else {
                    $tocResult .= str_repeat('</li></ul>',$curLev - $value['level']);
                }
            } else {
                $tocResult .= '</li>';
            }
            
            $curLev = $value['level'];
            if($curLev == $lStart) {
                $tocResult .= '<li class="TocTop"><a href="[~[*id*]~]#' . $value['anchor'] . '">' . strip_tags($value['header_in']) . '</a>';
            } else {
                $tocResult .= '<li><a href="[~[*id*]~]#' . $value['anchor'] . '">' . strip_tags($value['header_in']) . '</a>';
            }
        }
        
        $tocResult .= str_repeat('</li>',$curLev - $lStart) . '</ul>';
        
        if($tocTitle != '') {
            $tocTitle = '<span class="title">' . $tocTitle . '</span>';
        }
        
        $tocResult = '<div class="' . $tocClass . '">' . $tocTitle . $tocResult . '</div>';
        
        $modx->documentObject['content'] = $cont;
        $modx->setPlaceholder('toc',$tocResult);
    }
}
return;
//<?php
/**
 * evoTOC
 *
 * Plugin for automatically creating a table of contents on a page using anchors.
 *
 * @category    plugin
 * @version     1.0.0
 * @license     http://www.gnu.org/copyleft/gpl.html GNU Public License (GPL)
 * @internal    @properties &lStart=Start level;list;1,2,3,4,5,6;2 &lEnd=End level;list;1,2,3,4,5,6;3 &table_name=Transliteration;list;common,russian;common &tocTitle=Title;string;Contents &tocClass=CSS class;string;toc &tocAnchorType=Anchor type;list;1,2;1 &tocAnchorLen=Maximum anchor length;number;0 &exclude_docs=Exclude Documents by id (comma separated);string; &exclude_templates=Exclude Templates by id (comma separated);string;
 * @internal    @events OnLoadWebDocument
 * @internal    @modx_category Content
 * @internal    @legacy_names TOC
 * @internal    @installset base, sample
 */

/**
 * Available parameters:
 *
 * Start level - the starting level of the heading (H1 - H6)
 * End level - the ending level of the heading (H1 - H6)
 * Transliteration - will be used for the first type of anchors. TransAlias plugin tables are used.
 * Title - title for the table of contents. If the field is empty, the title is ignored.
 * CSS class - the style class that will be used in the table of contents (container and nested levels)
 * Anchor type - different variants of generating the anchor name. 1 - transliteration, 2 - numeration
 * Maximum anchor length - used in transliteration and limits the length of the anchor name
 * Exclude Documents by id - A comma separated list of documents id to exclude from the plugin and TOC generation
 * Exclude Templates by id - A comma separated list of templates id to exclude from the plugin and TOC generation
 *
 * Usage:
 *
 * After generation, the table of contents is placed in the global placeholder [+toc+]. Therefore, to display it, you just need to place this placeholder in the appropriate place.
 */

if(!defined('MODX_BASE_PATH')){die('What are you doing? Get out of here!');}

global $modx;

$exclude_docs = explode(',',$exclude_docs);
$exclude_templates = explode(',',$exclude_templates);
// exclude by doc id or template id
$doc_id = $modx -> documentObject['id'];
$template_id = $modx -> documentObject['template'];
if (!in_array($doc_id,$exclude_docs) && !in_array($template_id,$exclude_templates)) {
    $lStart = isset($lStart) ? $lStart : 2;
    $lEnd = isset($lEnd) ? $lEnd : 3;
    $tocTitle = isset($tocTitle) ? $tocTitle : '';
    $tocClass = isset($tocClass) ? $tocClass : 'toc';
    $tocAnchorType = (isset($tocAnchorType) and ($tocAnchorType == 2)) ? 2 : 1;
    $tocAnchorLen = (isset($tocAnchorLen) and ($tocAnchorLen > 0)) ? $tocAnchorLen : 0;

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

    // Create table of contents (rest of the code remains the same)
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
            
            $id = $modx->documentIdentifier;
            $url = $modx->makeUrl($id,'','','full');
            
            $curLev = $value['level'];
            if($curLev == $lStart) {
                $tocResult .= '<li class="TocTop"><a href="' . $url . '#' . $value['anchor'] . '">' . strip_tags($value['header_in']) . '</a>';
            } else {
                $tocResult .= '<li><a href="' . $url . '#' . $value['anchor'] . '">' . strip_tags($value['header_in']) . '</a>';
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
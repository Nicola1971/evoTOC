//<?php
/**
 * evoTOC
 *
 * Plugin for automatically creating a table of contents on a page using anchors.
 *
 * @author    Nicola Lambathakis http://www.tattoocms.it/
 * @category    plugin
 * @version     1.2.0
 * @license     http://www.gnu.org/copyleft/gpl.html GNU Public License (GPL)
 * @internal    @properties &lStart=Start level;list;1,2,3,4,5,6;2 &lEnd=End level;list;1,2,3,4,5,6;3 &tocTv=TV name for per-document levels (optional);string; &table_name=Transliteration;list;common,russian;common &tocTitle=Title;string;Contents &tocClass=CSS class;string;toc &tocAnchorType=Anchor type;list;1,2;1 &tocAnchorLen=Maximum anchor length;number;0 &include_templates=Include only these Templates by id (comma separated);string; &exclude_docs=Exclude Documents by id (comma separated);string; &exclude_templates=Exclude Templates by id (comma separated);string; &addBackToTop=Enable back to top;list;no,yes;no &backToTopText=Back to top text;string;Back To Top &backToTopTitle=Back to top title attribute;string;Back To Top &backToTopClass=Back to top CSS class;string;toc-back-to-top &backToTopLevels=Back to top on headings (comma separated);string;2 &tocAnchorId=TOC anchor ID;string;table-of-contents
 * @internal    @events OnLoadWebDocument
 * @internal    @modx_category Content
 * @internal    @legacy_names evoTOC
 * @internal    @installset base, sample
 */

if(!defined('MODX_BASE_PATH')){die('What are you doing? Get out of here!');}

if (!function_exists('generateBackToTopLink')) {
    function generateBackToTopLink($anchorId, $text, $title, $class) {
        return " <div class=\"{$class}-container\">" .
               "<a title=\"{$title}\" href=\"[~[*id*]~]#{$anchorId}\" " .
               "class=\"{$class}\">{$text}</a></div>";
    }
}

if (!function_exists('evoTocParseLevels')) {
    /**
     * Interpreta il valore della TV dei livelli:
     *  ''          -> null  (usa i parametri del plugin)
     *  '0' / 'off' -> false (toc disattivata, ancore mantenute)
     *  'N'         -> array(N, N)
     *  'N-M'       -> array(N, M)
     * Valori non validi -> null (fallback ai parametri del plugin)
     */
    function evoTocParseLevels($value) {
        $value = strtolower(trim((string)$value));
        if ($value === '') {
            return null;
        }
        if ($value === '0' || $value === 'off') {
            return false;
        }
        if (preg_match('/^([2-6])(?:\s*-\s*([2-6]))?$/', $value, $m)) {
            $start = (int)$m[1];
            $end = !empty($m[2]) ? (int)$m[2] : $start;
            return array(min($start, $end), max($start, $end));
        }
        return null;
    }
}

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
    // Compile patterns
    $headingPattern = "/<h([2-6])(.*?)>(.*?)<\/h[2-6]>/si";
    $anchorPattern = "/<a [\s\S]*?name=\"([\w]+)\"/";

    // Check for TOC placeholder early
    $tocPos = strpos($modx->documentObject['content'], '[+toc+]');
    $hasTocPlaceholder = $tocPos !== false;
    if (!$hasTocPlaceholder) {
        $tocPos = 0;
    }

    // Livelli del plugin (normalizzati: il pattern gestisce solo h2-h6)
    $lStart = isset($lStart) ? (int)$lStart : 2;
    $lEnd = isset($lEnd) ? (int)$lEnd : 3;
    $lStart = max(2, min(6, $lStart));
    $lEnd = max($lStart, min(6, $lEnd));

    // Livelli della toc: di default coincidono con quelli del plugin
    $tocStart = $lStart;
    $tocEnd = $lEnd;
    $tocEnabled = true;

    // Override per documento tramite TV (opzionale)
    $tocTv = isset($tocTv) ? trim($tocTv) : '';
    if ($tocTv !== '' && isset($modx->documentObject[$tocTv])) {
        $tvValue = $modx->documentObject[$tocTv];
        $tvValue = is_array($tvValue) ? $tvValue[1] : $tvValue; // TV: array(name, value, ...)
        $tvLevels = evoTocParseLevels($tvValue);
        if ($tvLevels === false) {
            $tocEnabled = false;
        } elseif (is_array($tvLevels)) {
            list($tocStart, $tocEnd) = $tvLevels;
        }
    }

    // Le ancore coprono sempre l'unione dei due intervalli,
    // cosi' restano stabili anche se la toc del documento viene ridotta
    $anchorStart = min($lStart, $tocStart);
    $anchorEnd = max($lEnd, $tocEnd);

    $tocTitle = isset($tocTitle) ? $tocTitle : '';
    $tocClass = isset($tocClass) ? $tocClass : 'toc';
    $tocAnchorType = (isset($tocAnchorType) and ($tocAnchorType == 2)) ? 2 : 1;
    $tocAnchorLen = (isset($tocAnchorLen) and ($tocAnchorLen > 0)) ? $tocAnchorLen : 0;
    $tocAnchorId = isset($tocAnchorId) ? $tocAnchorId : 'table-of-contents';

    // Back to top: attivo solo se la toc e' effettivamente presente
    $addBackToTop = (isset($addBackToTop) && $addBackToTop === 'yes') && $tocEnabled && $hasTocPlaceholder;
    $backToTopText = isset($backToTopText) ? $backToTopText : 'Back To Top';
    $backToTopTitle = isset($backToTopTitle) ? $backToTopTitle : 'Back To Top';
    $backToTopClass = isset($backToTopClass) ? $backToTopClass : 'toc-back-to-top';

    // Back to top levels: limitati all'intervallo della toc
    $backToTopLevels = isset($backToTopLevels) ? explode(',', $backToTopLevels) : array('2');
    $backToTopLevels = array_map('trim', $backToTopLevels);
    $backToTopLevels = array_filter($backToTopLevels, function($level) use ($tocStart, $tocEnd) {
        return $level >= $tocStart && $level <= $tocEnd;
    });

    // Transliteration setup
    $plugin_path = MODX_BASE_PATH.'assets/plugins/transalias';
    $table_name = isset($table_name) ? $table_name : 'russian';

    if (!class_exists('TransAlias')) {
        require_once $plugin_path.'/transalias.class.php';
    }
    $trans = new TransAlias($modx);

    $tocResult = '';
    $hArray = array(); // voci della toc
    $cont = $modx->documentObject['content'];

    // Add a named anchor at the top of the table of contents if back to top is enabled
    if ($addBackToTop) {
        $tocResult .= '<div id="' . $tocAnchorId . '"></div>';
    }

    if (preg_match_all($headingPattern, $cont, $matches, PREG_SET_ORDER | PREG_OFFSET_CAPTURE)) {
        foreach ($matches as $match) {
            $hLevel = (int)$match[1][0];  // The heading level (2-6)
            $hContent = $match[0][0];     // The full heading tag
            $position = $match[0][1];     // The position in the content

            if ($hLevel < $anchorStart || $hLevel > $anchorEnd) {
                continue;
            }

            // Check for existing anchor
            $hasAnchor = preg_match($anchorPattern, $hContent, $getAnchor);

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
                if ($addBackToTop && $position > $tocPos && in_array($hLevel, $backToTopLevels)) {
                    $modifiedHeading .= generateBackToTopLink(
                        $tocAnchorId,
                        $backToTopText,
                        $backToTopTitle,
                        $backToTopClass
                    );
                }

                $cont = str_replace($hContent, $modifiedHeading, $cont);
            }

            // Nell'indice solo i livelli della toc e solo gli heading dopo il placeholder
            if ($position > $tocPos && $hLevel >= $tocStart && $hLevel <= $tocEnd) {
                $hArray[] = array(
                    'level' => $hLevel,
                    'header_in' => $hContent,
                    'anchor' => $anchorName
                );
            }
        }
    }

    if ($hasTocPlaceholder) {
        // Le ancore vengono scritte anche se la toc e' disattivata
        $modx->documentObject['content'] = $cont;

        if ($tocEnabled && count($hArray) > 0) {
            // Costruzione lista annidata con stack dei livelli aperti
            $tocList = '';
            $stack = array();
            foreach ($hArray as $item) {
                $lev = $item['level'];
                if (empty($stack)) {
                    $tocList .= '<ul class="' . $tocClass . '_' . $lev . '">';
                    $stack[] = $lev;
                } elseif ($lev > end($stack)) {
                    $tocList .= '<ul class="lev2 ' . $tocClass . '_' . $lev . '">';
                    $stack[] = $lev;
                } else {
                    $tocList .= '</li>';
                    while (count($stack) > 1 && $lev < end($stack)) {
                        // Livello intermedio (es. H2 > H4 > H3): resta nella lista corrente
                        if ($lev > $stack[count($stack) - 2]) {
                            $stack[count($stack) - 1] = $lev;
                            break;
                        }
                        array_pop($stack);
                        $tocList .= '</ul></li>';
                    }
                    // Livello superiore alla radice (es. H3 iniziale seguito da H2):
                    // chiude la lista corrente e ne apre una nuova alla radice
                    if ($lev < end($stack)) {
                        $tocList .= '</ul><ul class="' . $tocClass . '_' . $lev . '">';
                        $stack = array($lev);
                    }
                }
                $liClass = ($lev == $tocStart) ? ' class="TocTop"' : '';
                $tocList .= '<li' . $liClass . '><a href="[~[*id*]~]#' . $item['anchor'] . '">' . strip_tags($item['header_in']) . '</a>';
            }
            $tocList .= '</li>' . str_repeat('</ul></li>', count($stack) - 1) . '</ul>';

            if ($tocTitle != '') {
                $tocTitle = '<span class="title">' . $tocTitle . '</span>';
            }

            $tocResult = '<div class="' . $tocClass . '">' . $tocTitle . $tocResult . $tocList . '</div>';
            $modx->setPlaceholder('toc', $tocResult);
        } else {
            $modx->setPlaceholder('toc', '');
        }
    }
}
return;
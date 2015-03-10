module Halogen.HTML
  ( HTML(..)
  , Attribute(..)
  , AttributeValue(..)
  
  , attributesToProps
  
  , text
  , raw
  , hashed
  
  -- Elements
  
  , a             , a_
  , abbr          , abbr_
  , acronym       , acronym_
  , address       , address_
  , applet        , applet_
  , area          , area_
  , article       , article_
  , aside         , aside_
  , audio         , audio_
  , b             , b_
  , base          , base_
  , basefont      , basefont_
  , bdi           , bdi_
  , bdo           , bdo_
  , big           , big_
  , blockquote    , blockquote_
  , body          , body_
  , br            , br_
  , button        , button_
  , canvas        , canvas_
  , caption       , caption_
  , center        , center_
  , cite          , cite_
  , code          , code_
  , col           , col_
  , colgroup      , colgroup_
  , datalist      , datalist_
  , dd            , dd_
  , del           , del_
  , details       , details_
  , dfn           , dfn_
  , dialog        , dialog_
  , dir           , dir_
  , div           , div_
  , dl            , dl_
  , dt            , dt_
  , em            , em_
  , embed         , embed_
  , fieldset      , fieldset_
  , figcaption    , figcaption_
  , figure        , figure_
  , font          , font_
  , footer        , footer_
  , form          , form_
  , frame         , frame_
  , frameset      , frameset_
  , h1            , h1_
  , h2            , h2_
  , h3            , h3_
  , h4            , h4_
  , h5            , h5_
  , h6            , h6_
  , head          , head_
  , header        , header_
  , hr            , hr_
  , html          , html_
  , i             , i_
  , iframe        , iframe_
  , img           , img_
  , input         , input_
  , ins           , ins_
  , kbd           , kbd_
  , keygen        , keygen_
  , label         , label_
  , legend        , legend_
  , li            , li_
  , link          , link_
  , main          , main_
  , map           , map_
  , mark          , mark_
  , menu          , menu_
  , menuitem      , menuitem_
  , meta          , meta_
  , meter         , meter_
  , nav           , nav_
  , noframes      , noframes_
  , noscript      , noscript_
  , object        , object_
  , ol            , ol_
  , optgroup      , optgroup_
  , option        , option_
  , output        , output_
  , p             , p_
  , param         , param_
  , pre           , pre_
  , progress      , progress_
  , q             , q_
  , rp            , rp_
  , rt            , rt_
  , ruby          , ruby_
  , s             , s_
  , samp          , samp_
  , script        , script_
  , section       , section_
  , select        , select_
  , small         , small_
  , source        , source_
  , span          , span_
  , strike        , strike_
  , strong        , strong_
  , style         , style_
  , sub           , sub_
  , summary       , summary_
  , sup           , sup_
  , table         , table_
  , tbody         , tbody_
  , td            , td_
  , textarea      , textarea_
  , tfoot         , tfoot_
  , th            , th_
  , thead         , thead_
  , time          , time_
  , title         , title_
  , tr            , tr_
  , track         , track_
  , tt            , tt_
  , u             , u_
  , ul            , ul_
  , var           , var_
  , video         , video_
  , wbr           , wbr_
  
  , renderHtml
  ) where

import Data.Maybe
import Data.Tuple
import Data.Foreign
import Data.Function
import Data.Monoid
import Data.Foldable (for_)
import Data.Hashable (Hashcode(), runHashcode)

import qualified Data.Array as A

import Control.Monad.Eff
import Control.Monad.Eff.Unsafe (unsafeInterleaveEff)
import Control.Monad.ST

import Halogen.Internal.VirtualDOM
import Halogen.HTML.Events.Handler

-- | A HTML attribute which can be used in a document of type `HTML i`.
data AttributeValue i
  = ValueAttribute Foreign
  | HandlerAttribute (Foreign -> EventHandler (Maybe i))

instance functorAttributeValue :: Functor AttributeValue where
  (<$>) _ (ValueAttribute v) = ValueAttribute v
  (<$>) f (HandlerAttribute k) = HandlerAttribute (((f <$>) <$>) <<< k)

data Attribute i = Attribute [Tuple String (AttributeValue i)]

instance functorAttribute :: Functor Attribute where
  (<$>) f (Attribute xs) = Attribute (A.map ((f <$>) <$>) xs)
  
instance semigroupAttribute :: Semigroup (Attribute i) where
  (<>) (Attribute xs) (Attribute ys) = Attribute (xs <> ys)

instance monoidAttribute :: Monoid (Attribute i) where
  mempty = Attribute []

-- | Convert a collection of attributes to `Props` by providing an event handler
attributesToProps :: forall i eff. (i -> Eff eff Unit) -> Attribute i -> Props
attributesToProps k (Attribute xs) = runProps do 
  props <- newProps
  for_ xs (addProp props)
  return props
  where
  addProp :: forall h eff. STProps h -> Tuple String (AttributeValue i) -> Eff (st :: ST h | eff) Unit
  addProp props (Tuple key (ValueAttribute value)) = runFn3 prop key value props
  addProp props (Tuple key (HandlerAttribute f)) = runFn3 handlerProp key handler props
    where
    handler :: Foreign -> Eff eff Unit
    handler e = do
      m <- unsafeInterleaveEff $ runEventHandler (unsafeFromForeign e) (f e)
      for_ m k

-- | The `HTML` type represents HTML documents before being rendered to the virtual DOM, and ultimately,
-- | the actual DOM.
-- |
-- | This representation is useful because it supports various typed transformations. It also gives a 
-- | strongly-typed representation for the events which can be generated by a document.
-- |
-- | The type parameter `i` represents the type of events which can be generated by this document.
data HTML i
  = Text String
  | Element String (Attribute i) [HTML i]
  | Hashed Hashcode (Unit -> HTML i)
  | Raw VTree
    
instance functorHTML :: Functor HTML where
  (<$>) _ (Text s) = Text s
  (<$>) f (Element name attribs children) = Element name (f <$> attribs) (Data.Array.map (f <$>) children)
  (<$>) f (Hashed hash g) = Hashed hash ((f <$>) <<< g)
  (<$>) _ (Raw vtree) = Raw vtree

-- | Render a `HTML` document to a virtual DOM node
renderHtml :: forall i eff. (i -> Eff eff Unit) -> HTML i -> VTree
renderHtml _ (Text s) = vtext s
renderHtml k (Element name attribs children) = vnode name (attributesToProps k attribs) (Data.Array.map (renderHtml k) children)
renderHtml k (Hashed h html) = runFn2 hash (mkFn0 \_ -> renderHtml k (html unit)) h
renderHtml _ (Raw vtree) = vtree

text :: forall i. String -> HTML i
text = Text

-- | Created a "hashed" HTML document, which only gets re-rendered when the hash changes
hashed :: forall i. Hashcode -> (Unit -> HTML i) -> HTML i
hashed = Hashed

-- | Create a HTML document from a raw `VTree`.
-- |
-- | This function is useful when embedding third-party widgets in HTML documents using the `widget` function, and
-- | is considered an advanced feature. Use at your own risk.
raw :: forall i. VTree -> HTML i
raw = Raw

a :: forall i. Attribute i -> [HTML i] -> HTML i
a = Element "a"

a_ :: forall i. [HTML i] -> HTML i
a_ = a mempty

abbr :: forall i. Attribute i -> [HTML i] -> HTML i
abbr = Element "abbr"

abbr_ :: forall i. [HTML i] -> HTML i
abbr_ = abbr mempty

acronym :: forall i. Attribute i -> [HTML i] -> HTML i
acronym = Element "acronym"

acronym_ :: forall i. [HTML i] -> HTML i
acronym_ = acronym mempty

address :: forall i. Attribute i -> [HTML i] -> HTML i
address = Element "address"

address_ :: forall i. [HTML i] -> HTML i
address_ = address mempty

applet :: forall i. Attribute i -> [HTML i] -> HTML i
applet = Element "applet"

applet_ :: forall i. [HTML i] -> HTML i
applet_ = applet mempty

area :: forall i. Attribute i -> [HTML i] -> HTML i
area = Element "area"

area_ :: forall i. [HTML i] -> HTML i
area_ = area mempty

article :: forall i. Attribute i -> [HTML i] -> HTML i
article = Element "article"

article_ :: forall i. [HTML i] -> HTML i
article_ = article mempty

aside :: forall i. Attribute i -> [HTML i] -> HTML i
aside = Element "aside"

aside_ :: forall i. [HTML i] -> HTML i
aside_ = aside mempty

audio :: forall i. Attribute i -> [HTML i] -> HTML i
audio = Element "audio"

audio_ :: forall i. [HTML i] -> HTML i
audio_ = audio mempty

b :: forall i. Attribute i -> [HTML i] -> HTML i
b = Element "b"

b_ :: forall i. [HTML i] -> HTML i
b_ = b mempty

base :: forall i. Attribute i -> [HTML i] -> HTML i
base = Element "base"

base_ :: forall i. [HTML i] -> HTML i
base_ = base mempty

basefont :: forall i. Attribute i -> [HTML i] -> HTML i
basefont = Element "basefont"

basefont_ :: forall i. [HTML i] -> HTML i
basefont_ = basefont mempty

bdi :: forall i. Attribute i -> [HTML i] -> HTML i
bdi = Element "bdi"

bdi_ :: forall i. [HTML i] -> HTML i
bdi_ = bdi mempty

bdo :: forall i. Attribute i -> [HTML i] -> HTML i
bdo = Element "bdo"

bdo_ :: forall i. [HTML i] -> HTML i
bdo_ = bdo mempty

big :: forall i. Attribute i -> [HTML i] -> HTML i
big = Element "big"

big_ :: forall i. [HTML i] -> HTML i
big_ = big mempty

blockquote :: forall i. Attribute i -> [HTML i] -> HTML i
blockquote = Element "blockquote"

blockquote_ :: forall i. [HTML i] -> HTML i
blockquote_ = blockquote mempty

body :: forall i. Attribute i -> [HTML i] -> HTML i
body = Element "body"

body_ :: forall i. [HTML i] -> HTML i
body_ = body mempty

br :: forall i. Attribute i -> [HTML i] -> HTML i
br = Element "br"

br_ :: forall i. [HTML i] -> HTML i
br_ = br mempty

button :: forall i. Attribute i -> [HTML i] -> HTML i
button = Element "button"

button_ :: forall i. [HTML i] -> HTML i
button_ = button mempty

canvas :: forall i. Attribute i -> [HTML i] -> HTML i
canvas = Element "canvas"

canvas_ :: forall i. [HTML i] -> HTML i
canvas_ = canvas mempty

caption :: forall i. Attribute i -> [HTML i] -> HTML i
caption = Element "caption"

caption_ :: forall i. [HTML i] -> HTML i
caption_ = caption mempty

center :: forall i. Attribute i -> [HTML i] -> HTML i
center = Element "center"

center_ :: forall i. [HTML i] -> HTML i
center_ = center mempty

cite :: forall i. Attribute i -> [HTML i] -> HTML i
cite = Element "cite"

cite_ :: forall i. [HTML i] -> HTML i
cite_ = cite mempty

code :: forall i. Attribute i -> [HTML i] -> HTML i
code = Element "code"

code_ :: forall i. [HTML i] -> HTML i
code_ = code mempty

col :: forall i. Attribute i -> [HTML i] -> HTML i
col = Element "col"

col_ :: forall i. [HTML i] -> HTML i
col_ = col mempty

colgroup :: forall i. Attribute i -> [HTML i] -> HTML i
colgroup = Element "colgroup"

colgroup_ :: forall i. [HTML i] -> HTML i
colgroup_ = colgroup mempty

datalist :: forall i. Attribute i -> [HTML i] -> HTML i
datalist = Element "datalist"

datalist_ :: forall i. [HTML i] -> HTML i
datalist_ = datalist mempty

dd :: forall i. Attribute i -> [HTML i] -> HTML i
dd = Element "dd"

dd_ :: forall i. [HTML i] -> HTML i
dd_ = dd mempty

del :: forall i. Attribute i -> [HTML i] -> HTML i
del = Element "del"

del_ :: forall i. [HTML i] -> HTML i
del_ = del mempty

details :: forall i. Attribute i -> [HTML i] -> HTML i
details = Element "details"

details_ :: forall i. [HTML i] -> HTML i
details_ = details mempty

dfn :: forall i. Attribute i -> [HTML i] -> HTML i
dfn = Element "dfn"

dfn_ :: forall i. [HTML i] -> HTML i
dfn_ = dfn mempty

dialog :: forall i. Attribute i -> [HTML i] -> HTML i
dialog = Element "dialog"

dialog_ :: forall i. [HTML i] -> HTML i
dialog_ = dialog mempty

dir :: forall i. Attribute i -> [HTML i] -> HTML i
dir = Element "dir"

dir_ :: forall i. [HTML i] -> HTML i
dir_ = dir mempty

div :: forall i. Attribute i -> [HTML i] -> HTML i
div = Element "div"

div_ :: forall i. [HTML i] -> HTML i
div_ = div mempty

dl :: forall i. Attribute i -> [HTML i] -> HTML i
dl = Element "dl"

dl_ :: forall i. [HTML i] -> HTML i
dl_ = dl mempty

dt :: forall i. Attribute i -> [HTML i] -> HTML i
dt = Element "dt"

dt_ :: forall i. [HTML i] -> HTML i
dt_ = dt mempty

em :: forall i. Attribute i -> [HTML i] -> HTML i
em = Element "em"

em_ :: forall i. [HTML i] -> HTML i
em_ = em mempty

embed :: forall i. Attribute i -> [HTML i] -> HTML i
embed = Element "embed"

embed_ :: forall i. [HTML i] -> HTML i
embed_ = embed mempty

fieldset :: forall i. Attribute i -> [HTML i] -> HTML i
fieldset = Element "fieldset"

fieldset_ :: forall i. [HTML i] -> HTML i
fieldset_ = fieldset mempty

figcaption :: forall i. Attribute i -> [HTML i] -> HTML i
figcaption = Element "figcaption"

figcaption_ :: forall i. [HTML i] -> HTML i
figcaption_ = figcaption mempty

figure :: forall i. Attribute i -> [HTML i] -> HTML i
figure = Element "figure"

figure_ :: forall i. [HTML i] -> HTML i
figure_ = figure mempty

font :: forall i. Attribute i -> [HTML i] -> HTML i
font = Element "font"

font_ :: forall i. [HTML i] -> HTML i
font_ = font mempty

footer :: forall i. Attribute i -> [HTML i] -> HTML i
footer = Element "footer"

footer_ :: forall i. [HTML i] -> HTML i
footer_ = footer mempty

form :: forall i. Attribute i -> [HTML i] -> HTML i
form = Element "form"

form_ :: forall i. [HTML i] -> HTML i
form_ = form mempty

frame :: forall i. Attribute i -> [HTML i] -> HTML i
frame = Element "frame"

frame_ :: forall i. [HTML i] -> HTML i
frame_ = frame mempty

frameset :: forall i. Attribute i -> [HTML i] -> HTML i
frameset = Element "frameset"

frameset_ :: forall i. [HTML i] -> HTML i
frameset_ = frameset mempty

h1 :: forall i. Attribute i -> [HTML i] -> HTML i
h1 = Element "h1"

h1_ :: forall i. [HTML i] -> HTML i
h1_ = h1 mempty

h2 :: forall i. Attribute i -> [HTML i] -> HTML i
h2 = Element "h2"

h2_ :: forall i. [HTML i] -> HTML i
h2_ = h2 mempty

h3 :: forall i. Attribute i -> [HTML i] -> HTML i
h3 = Element "h3"

h3_ :: forall i. [HTML i] -> HTML i
h3_ = h3 mempty

h4 :: forall i. Attribute i -> [HTML i] -> HTML i
h4 = Element "h4"

h4_ :: forall i. [HTML i] -> HTML i
h4_ = h4 mempty

h5 :: forall i. Attribute i -> [HTML i] -> HTML i
h5 = Element "h5"

h5_ :: forall i. [HTML i] -> HTML i
h5_ = h5 mempty

h6 :: forall i. Attribute i -> [HTML i] -> HTML i
h6 = Element "h6"

h6_ :: forall i. [HTML i] -> HTML i
h6_ = h6 mempty

head :: forall i. Attribute i -> [HTML i] -> HTML i
head = Element "head"

head_ :: forall i. [HTML i] -> HTML i
head_ = head mempty

header :: forall i. Attribute i -> [HTML i] -> HTML i
header = Element "header"

header_ :: forall i. [HTML i] -> HTML i
header_ = header mempty

hr :: forall i. Attribute i -> [HTML i] -> HTML i
hr = Element "hr"

hr_ :: forall i. [HTML i] -> HTML i
hr_ = hr mempty

html :: forall i. Attribute i -> [HTML i] -> HTML i
html = Element "html"

html_ :: forall i. [HTML i] -> HTML i
html_ = html mempty

i :: forall i. Attribute i -> [HTML i] -> HTML i
i = Element "i"

i_ :: forall i. [HTML i] -> HTML i
i_ = i mempty

iframe :: forall i. Attribute i -> [HTML i] -> HTML i
iframe = Element "iframe"

iframe_ :: forall i. [HTML i] -> HTML i
iframe_ = iframe mempty

img :: forall i. Attribute i -> [HTML i] -> HTML i
img = Element "img"

img_ :: forall i. [HTML i] -> HTML i
img_ = img mempty

input :: forall i. Attribute i -> [HTML i] -> HTML i
input = Element "input"

input_ :: forall i. [HTML i] -> HTML i
input_ = input mempty

ins :: forall i. Attribute i -> [HTML i] -> HTML i
ins = Element "ins"

ins_ :: forall i. [HTML i] -> HTML i
ins_ = ins mempty

kbd :: forall i. Attribute i -> [HTML i] -> HTML i
kbd = Element "kbd"

kbd_ :: forall i. [HTML i] -> HTML i
kbd_ = kbd mempty

keygen :: forall i. Attribute i -> [HTML i] -> HTML i
keygen = Element "keygen"

keygen_ :: forall i. [HTML i] -> HTML i
keygen_ = keygen mempty

label :: forall i. Attribute i -> [HTML i] -> HTML i
label = Element "label"

label_ :: forall i. [HTML i] -> HTML i
label_ = label mempty

legend :: forall i. Attribute i -> [HTML i] -> HTML i
legend = Element "legend"

legend_ :: forall i. [HTML i] -> HTML i
legend_ = legend mempty

li :: forall i. Attribute i -> [HTML i] -> HTML i
li = Element "li"

li_ :: forall i. [HTML i] -> HTML i
li_ = li mempty

link :: forall i. Attribute i -> [HTML i] -> HTML i
link = Element "link"

link_ :: forall i. [HTML i] -> HTML i
link_ = link mempty

main :: forall i. Attribute i -> [HTML i] -> HTML i
main = Element "main"

main_ :: forall i. [HTML i] -> HTML i
main_ = main mempty

map :: forall i. Attribute i -> [HTML i] -> HTML i
map = Element "map"

map_ :: forall i. [HTML i] -> HTML i
map_ = map mempty

mark :: forall i. Attribute i -> [HTML i] -> HTML i
mark = Element "mark"

mark_ :: forall i. [HTML i] -> HTML i
mark_ = mark mempty

menu :: forall i. Attribute i -> [HTML i] -> HTML i
menu = Element "menu"

menu_ :: forall i. [HTML i] -> HTML i
menu_ = menu mempty

menuitem :: forall i. Attribute i -> [HTML i] -> HTML i
menuitem = Element "menuitem"

menuitem_ :: forall i. [HTML i] -> HTML i
menuitem_ = menuitem mempty

meta :: forall i. Attribute i -> [HTML i] -> HTML i
meta = Element "meta"

meta_ :: forall i. [HTML i] -> HTML i
meta_ = meta mempty

meter :: forall i. Attribute i -> [HTML i] -> HTML i
meter = Element "meter"

meter_ :: forall i. [HTML i] -> HTML i
meter_ = meter mempty

nav :: forall i. Attribute i -> [HTML i] -> HTML i
nav = Element "nav"

nav_ :: forall i. [HTML i] -> HTML i
nav_ = nav mempty

noframes :: forall i. Attribute i -> [HTML i] -> HTML i
noframes = Element "noframes"

noframes_ :: forall i. [HTML i] -> HTML i
noframes_ = noframes mempty

noscript :: forall i. Attribute i -> [HTML i] -> HTML i
noscript = Element "noscript"

noscript_ :: forall i. [HTML i] -> HTML i
noscript_ = noscript mempty

object :: forall i. Attribute i -> [HTML i] -> HTML i
object = Element "object"

object_ :: forall i. [HTML i] -> HTML i
object_ = object mempty

ol :: forall i. Attribute i -> [HTML i] -> HTML i
ol = Element "ol"

ol_ :: forall i. [HTML i] -> HTML i
ol_ = ol mempty

optgroup :: forall i. Attribute i -> [HTML i] -> HTML i
optgroup = Element "optgroup"

optgroup_ :: forall i. [HTML i] -> HTML i
optgroup_ = optgroup mempty

option :: forall i. Attribute i -> [HTML i] -> HTML i
option = Element "option"

option_ :: forall i. [HTML i] -> HTML i
option_ = option mempty

output :: forall i. Attribute i -> [HTML i] -> HTML i
output = Element "output"

output_ :: forall i. [HTML i] -> HTML i
output_ = output mempty

p :: forall i. Attribute i -> [HTML i] -> HTML i
p = Element "p"

p_ :: forall i. [HTML i] -> HTML i
p_ = p mempty

param :: forall i. Attribute i -> [HTML i] -> HTML i
param = Element "param"

param_ :: forall i. [HTML i] -> HTML i
param_ = param mempty

pre :: forall i. Attribute i -> [HTML i] -> HTML i
pre = Element "pre"

pre_ :: forall i. [HTML i] -> HTML i
pre_ = pre mempty

progress :: forall i. Attribute i -> [HTML i] -> HTML i
progress = Element "progress"

progress_ :: forall i. [HTML i] -> HTML i
progress_ = progress mempty

q :: forall i. Attribute i -> [HTML i] -> HTML i
q = Element "q"

q_ :: forall i. [HTML i] -> HTML i
q_ = q mempty

rp :: forall i. Attribute i -> [HTML i] -> HTML i
rp = Element "rp"

rp_ :: forall i. [HTML i] -> HTML i
rp_ = rp mempty

rt :: forall i. Attribute i -> [HTML i] -> HTML i
rt = Element "rt"

rt_ :: forall i. [HTML i] -> HTML i
rt_ = rt mempty

ruby :: forall i. Attribute i -> [HTML i] -> HTML i
ruby = Element "ruby"

ruby_ :: forall i. [HTML i] -> HTML i
ruby_ = ruby mempty

s :: forall i. Attribute i -> [HTML i] -> HTML i
s = Element "s"

s_ :: forall i. [HTML i] -> HTML i
s_ = s mempty

samp :: forall i. Attribute i -> [HTML i] -> HTML i
samp = Element "samp"

samp_ :: forall i. [HTML i] -> HTML i
samp_ = samp mempty

script :: forall i. Attribute i -> [HTML i] -> HTML i
script = Element "script"

script_ :: forall i. [HTML i] -> HTML i
script_ = script mempty

section :: forall i. Attribute i -> [HTML i] -> HTML i
section = Element "section"

section_ :: forall i. [HTML i] -> HTML i
section_ = section mempty

select :: forall i. Attribute i -> [HTML i] -> HTML i
select = Element "select"

select_ :: forall i. [HTML i] -> HTML i
select_ = select mempty

small :: forall i. Attribute i -> [HTML i] -> HTML i
small = Element "small"

small_ :: forall i. [HTML i] -> HTML i
small_ = small mempty

source :: forall i. Attribute i -> [HTML i] -> HTML i
source = Element "source"

source_ :: forall i. [HTML i] -> HTML i
source_ = source mempty

span :: forall i. Attribute i -> [HTML i] -> HTML i
span = Element "span"

span_ :: forall i. [HTML i] -> HTML i
span_ = span mempty

strike :: forall i. Attribute i -> [HTML i] -> HTML i
strike = Element "strike"

strike_ :: forall i. [HTML i] -> HTML i
strike_ = strike mempty

strong :: forall i. Attribute i -> [HTML i] -> HTML i
strong = Element "strong"

strong_ :: forall i. [HTML i] -> HTML i
strong_ = strong mempty

style :: forall i. Attribute i -> [HTML i] -> HTML i
style = Element "style"

style_ :: forall i. [HTML i] -> HTML i
style_ = style mempty

sub :: forall i. Attribute i -> [HTML i] -> HTML i
sub = Element "sub"

sub_ :: forall i. [HTML i] -> HTML i
sub_ = sub mempty

summary :: forall i. Attribute i -> [HTML i] -> HTML i
summary = Element "summary"

summary_ :: forall i. [HTML i] -> HTML i
summary_ = summary mempty

sup :: forall i. Attribute i -> [HTML i] -> HTML i
sup = Element "sup"

sup_ :: forall i. [HTML i] -> HTML i
sup_ = sup mempty

table :: forall i. Attribute i -> [HTML i] -> HTML i
table = Element "table"

table_ :: forall i. [HTML i] -> HTML i
table_ = table mempty

tbody :: forall i. Attribute i -> [HTML i] -> HTML i
tbody = Element "tbody"

tbody_ :: forall i. [HTML i] -> HTML i
tbody_ = tbody mempty

td :: forall i. Attribute i -> [HTML i] -> HTML i
td = Element "td"

td_ :: forall i. [HTML i] -> HTML i
td_ = td mempty

textarea :: forall i. Attribute i -> [HTML i] -> HTML i
textarea = Element "textarea"

textarea_ :: forall i. [HTML i] -> HTML i
textarea_ = textarea mempty

tfoot :: forall i. Attribute i -> [HTML i] -> HTML i
tfoot = Element "tfoot"

tfoot_ :: forall i. [HTML i] -> HTML i
tfoot_ = tfoot mempty

th :: forall i. Attribute i -> [HTML i] -> HTML i
th = Element "th"

th_ :: forall i. [HTML i] -> HTML i
th_ = th mempty

thead :: forall i. Attribute i -> [HTML i] -> HTML i
thead = Element "thead"

thead_ :: forall i. [HTML i] -> HTML i
thead_ = thead mempty

time :: forall i. Attribute i -> [HTML i] -> HTML i
time = Element "time"

time_ :: forall i. [HTML i] -> HTML i
time_ = time mempty

title :: forall i. Attribute i -> [HTML i] -> HTML i
title = Element "title"

title_ :: forall i. [HTML i] -> HTML i
title_ = title mempty

tr :: forall i. Attribute i -> [HTML i] -> HTML i
tr = Element "tr"

tr_ :: forall i. [HTML i] -> HTML i
tr_ = tr mempty

track :: forall i. Attribute i -> [HTML i] -> HTML i
track = Element "track"

track_ :: forall i. [HTML i] -> HTML i
track_ = track mempty

tt :: forall i. Attribute i -> [HTML i] -> HTML i
tt = Element "tt"

tt_ :: forall i. [HTML i] -> HTML i
tt_ = tt mempty

u :: forall i. Attribute i -> [HTML i] -> HTML i
u = Element "u"

u_ :: forall i. [HTML i] -> HTML i
u_ = u mempty

ul :: forall i. Attribute i -> [HTML i] -> HTML i
ul = Element "ul"

ul_ :: forall i. [HTML i] -> HTML i
ul_ = ul mempty

var :: forall i. Attribute i -> [HTML i] -> HTML i
var = Element "var"

var_ :: forall i. [HTML i] -> HTML i
var_ = var mempty

video :: forall i. Attribute i -> [HTML i] -> HTML i
video = Element "video"

video_ :: forall i. [HTML i] -> HTML i
video_ = video mempty

wbr :: forall i. Attribute i -> [HTML i] -> HTML i
wbr = Element "wbr"

wbr_ :: forall i. [HTML i] -> HTML i
wbr_ = wbr mempty

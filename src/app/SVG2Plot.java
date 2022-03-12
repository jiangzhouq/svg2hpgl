package app;
import javax.xml.transform.*;
import javax.xml.transform.stream.StreamResult;
import javax.xml.transform.stream.StreamSource;
import java.io.File;
import java.io.FileWriter;
import java.io.IOException;
import java.io.InputStream;
import java.io.Writer;
import java.net.URISyntaxException;
import java.nio.charset.Charset;

public class SVG2Plot {
    public static void main(final String[] args) throws IOException, URISyntaxException, TransformerException {
        try {
            File infile=null, outfile=null;
            if (args.length==2) {
                infile = new File(args[0]);
                outfile = new File(args[1]);
                final SVG2Plot instance = new SVG2Plot();
                instance.convertSVG2Plot(infile, outfile);
                System.exit(0);
            } else {
                System.out.println("Use: java "+SVG2Plot.class.getName()+" svgfile hpglfile");
                throw new Exception("No Filesnames given. Exit.");
            }
        } catch (Exception e) {
            System.err.println(e.getMessage());
            System.exit(1);
        }
    }
    /**
     * Conversion routine to translate from an SVG file to a HPGL/1 file.
     * The HPGL translation is done entirely in the XSLT transformation file. The HPGL level
     * can be adjusted there and defaults to HPGL/1. 
     * More complex instruction like Bezier Curves introduced in HPGL/2 are emulated by
     * HPGL/1 pathsegments. 
     * Note: If using bezier curves or the like, the output is expected to grow significantly
     * and plot speed will be slowed down. It is advisable to do the conversion from curves to
     * segments in the source software and to apply a path simplification then.
     * Alternatively, there is a python utility which can do some simplification steps.
     * @param infile SVG input file
     * @param outfile HPGL output file
     * @throws Exception
     */
    private void convertSVG2Plot(final File infile, final File outfile) throws Exception {
        final TransformerFactory factory = TransformerFactory.newInstance();
        final Source xslt = new StreamSource(this.getClass().getResourceAsStream("svg2plt.xslt"));
        final Transformer transformer = factory.newTransformer(xslt);
        final Source text = new StreamSource(infile);
        final Writer fw = new FileWriter(outfile, Charset.forName("US-ASCII"));

        transformer.transform(text, new StreamResult(fw));
    }
}
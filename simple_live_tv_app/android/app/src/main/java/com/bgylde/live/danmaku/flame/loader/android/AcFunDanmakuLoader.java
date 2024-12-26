package com.bgylde.live.danmaku.flame.loader.android;

import java.io.InputStream;

import com.bgylde.live.danmaku.flame.loader.ILoader;
import com.bgylde.live.danmaku.flame.loader.IllegalDataException;
import com.bgylde.live.danmaku.flame.parser.android.JSONSource;

import android.net.Uri;
/**
 * Ac danmaku loader
 * @author yrom
 *
 */
public class AcFunDanmakuLoader implements ILoader {
	private AcFunDanmakuLoader(){}
	private static volatile AcFunDanmakuLoader instance;
	private JSONSource dataSource;
	
	public static ILoader instance() {
		if(instance == null){
			synchronized (AcFunDanmakuLoader.class){
				if(instance == null)
					instance = new AcFunDanmakuLoader();
			}
		}
		return instance;
	}
	
	@Override
	public JSONSource getDataSource() {
		return dataSource;
	}
	
	@Override
	public void load(String uri) throws IllegalDataException {
		try {
			dataSource = new JSONSource(Uri.parse(uri));
		} catch (Exception e) {
			throw new IllegalDataException(e);
		}
	}

	@Override
	public void load(InputStream in) throws IllegalDataException {
		try {
			dataSource = new JSONSource(in);
		} catch (Exception e) {
			throw new IllegalDataException(e);
		}
	}
	

}

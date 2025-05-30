#import <Foundation/Foundation.h>
#import "LocalCoreDataService.h"
#import "PostServiceOptions.h"

@class AbstractPost;
@class Blog;
@class Post;
@class Page;
@class RemotePost;
@class RemoteUser;
@class PostServiceRemoteFactory;
@class PostServiceUploadingList;

NS_ASSUME_NONNULL_BEGIN

typedef void(^PostServiceSyncSuccess)(NSArray<AbstractPost *> * _Nullable posts);
typedef void(^PostServiceSyncFailure)(NSError * _Nullable error);

typedef NSString * PostServiceType NS_TYPED_ENUM;
extern PostServiceType const PostServiceTypePost;
extern PostServiceType const PostServiceTypePage;
extern PostServiceType const PostServiceTypeAny;
extern const NSUInteger PostServiceDefaultNumberToSync;


@interface PostService : LocalCoreDataService

// This is public so it can be accessed from Swift extensions.
@property (nonnull, strong, nonatomic) PostServiceRemoteFactory *postServiceRemoteFactory;

- (instancetype)initWithManagedObjectContext:(NSManagedObjectContext *)context
                    postServiceRemoteFactory:(PostServiceRemoteFactory *)postServiceRemoteFactory NS_DESIGNATED_INITIALIZER;

/**
 Sync a specific post from the API

 @param postID The ID of the post to sync
 @param blog The blog that has the post.
 @param success A success block
 @param failure A failure block
 */
- (void)getPostWithID:(NSNumber *)postID
              forBlog:(Blog *)blog
              success:(void (^)(AbstractPost *post))success
              failure:(void (^)(NSError *))failure __attribute__((deprecated("Use `PostRepository` instead")));

/**
 Sync an initial batch of posts from the specified blog.
 Please note that success and/or failure are called in the context of the
 NSManagedObjectContext supplied when the PostService was initialized, and may not
 run on the main thread.

 @param postType The type (post or page) of post to sync
 @param blog The blog that has the posts.
 @param success A success block
 @param failure A failure block
 */
- (void)syncPostsOfType:(PostServiceType)postType
                forBlog:(Blog *)blog
                success:(PostServiceSyncSuccess)success
                failure:(PostServiceSyncFailure)failure;

/**
 Sync a batch of posts with the specified options from the specified blog.
 Please note that success and/or failure are called in the context of the
 NSManagedObjectContext supplied when the PostService was initialized, and may not
 run on the main thread.
 
 @param postType The type (post or page) of post to sync
 @param options Sync options for specific request parameters.
 @param blog The blog that has the posts.
 @param success A success block
 @param failure A failure block
 */
- (void)syncPostsOfType:(PostServiceType)postType
            withOptions:(PostServiceSyncOptions *)options
                forBlog:(Blog *)blog
                success:(PostServiceSyncSuccess)success
                failure:(PostServiceSyncFailure)failure;

/**
 Syncs local changes on a post back to the server.

 If the post only exists on the device, it will be created.

 @param post The post or page to upload
 @param success A success block.  If the post object exists locally (in CoreData) when the upload
        succeeds, then this block will also return a pointer to the updated local AbstractPost
        object.  It's important to note this object may not be the same one as the `post` input 
        parameter, since if the input post was a revision, it will no longer exist once the upload
        succeeds.
 @param failure A failure block
 */
- (void)uploadPost:(AbstractPost *)post
           success:(nullable void (^)(AbstractPost *post))success
           failure:(void (^)(NSError * _Nullable error))failure;

/**
 The same as `uploadPost:success:failure`

 Setting `forceDraftIfCreating` to `YES` is useful if we want to create a post in the server
 with the intention of making it available for preview. If we create the post as is, and the user
 has set its `status` to `.published`, then we would publishing the post even if we just
 wanted to preview it!

 Another use case of `forceDraftIfCreating` is to create the post in the background so we can
 periodically auto-save it. Again, we'd still want to create it as a `.draft` status.
 */
- (void)uploadPost:(AbstractPost *)post
forceDraftIfCreating:(BOOL)forceDraftIfCreating
           success:(nullable void (^)(AbstractPost * _Nullable post))success
           failure:(nullable void (^)(NSError * _Nullable error))failure;

/**
 Saves a post to the server.
 
 @param post The post or page to be saved
 @param success A success block.  If the post object exists locally (in CoreData) when the upload
 succeeds, then this block will also return a pointer to the updated local AbstractPost
 object.  It's important to note this object may not be the same one as the `post` input
 parameter
 @param failure A failure block
 */
- (void)autoSave:(AbstractPost *)post
         success:(nullable void (^)(AbstractPost *post, NSString *previewURL))success
         failure:(void (^)(NSError * _Nullable error))failure;

@end

NS_ASSUME_NONNULL_END
